//./worker "Map" "0" "1" "/var/data/media_util/out/" "3704" "/var/data/media_files_4gb/" "0" "3703" "out"

//./worker Reduce "/var/data/media_util/out/" "/var/data/media_util/temp-0/" 0 out "/usr/bin/ffmpeg" "-f concat -safe 0 -i" "-preset ultrafast -crf 50" "52fdfc07"

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
)

type ByKey []KeyValue

func (a ByKey) Len() int           { return len(a) }
func (a ByKey) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByKey) Less(i, j int) bool { return a[i].Key < a[j].Key }

type Mapper struct {
	filenames   []string
	numReducers int
	mapNumber   string
	dirPath     string
	mediaPath   string
	bucketMax   int
	filename    string
}

type Reducer struct {
	reducerNum             string
	filePath               string
	targetPath             string
	filename               string
	command                string
	commandParamInputFile  string
	commandParamOutputFile string
	guid                   string
}

type KeyValue struct {
	Key   int
	Value string
}

func main(){
	
	if os.Args[1] == "Map" {
		obj := createObjMap()
		w := _init_map(obj)
		CallnMonitorMap(w)
	} else {
		obj := createObjReducer()
		w := _init_reduce(obj)
		WorkerInReducer(w)
		log.Println("Successfully executed " + w.guid)
	}
}

func createObjMap() map[string]interface{}{
	obj := make(map[string]interface{})
	obj["mapNumber"],_=strconv.ParseFloat(os.Args[2], 64)
	obj["totalReducer"],_=strconv.ParseFloat(os.Args[3], 64)
	obj["dirPath"]=os.Args[4]
	obj["bucketMax"],_=strconv.ParseFloat(os.Args[5], 64)
	obj["mediaPath"]=os.Args[6]
	obj["startFrame"],_=strconv.ParseFloat(os.Args[7], 64)
	obj["endFrame"],_=strconv.ParseFloat(os.Args[8], 64)
	obj["filename"]=os.Args[9]
	return obj
}

func createObjReducer() map[string]interface{}{
	obj := make(map[string]interface{})
	obj["dirPath"]=os.Args[2]
	obj["targetPath"]=os.Args[3]
	obj["reducerNum"],_=strconv.ParseFloat(os.Args[4], 64)
	obj["command"]=os.Args[6]
	obj["commandParamInputFile"]=os.Args[7]
	obj["commandParamOutputFile"]=os.Args[8]
	obj["filename"]=os.Args[5]
	obj["guid"]=os.Args[9]
	return obj
}

func CallnMonitorMap(w *Mapper) {
	kva := Map(w.mediaPath, w.filenames, w.filename)
	log.Println("Mapping is done")
	kvas := PartitionToReducers(kva, w)
	log.Println("Partitioning is done")
	for i, _ := range kvas {
		if len(kvas[i]) > 0 {
			WriteToJSONFile(w, kvas[i], i)
		}
	}
}

func WorkerInReducer(w *Reducer) {

	var intermediate []KeyValue
	files, err := ioutil.ReadDir(w.filePath)
	if err != nil {
		log.Fatal(err)
	}
	for _, f := range files {
		//log.Println(f.Name())
		file, err := ioutil.ReadFile(w.filePath + "/" + f.Name())
		if err != nil {
			log.Fatal(err)
		}
		var interim []KeyValue
		err2 := json.Unmarshal(file, &interim)
		if err2 != nil {
			fmt.Println("error:", err2)
		}
		intermediate = append(intermediate, interim...)
	}
	sort.Sort(ByKey(intermediate))
	sortedStrings := make([]string, len(intermediate))
	for _, k := range intermediate {
		sortedStrings = append(sortedStrings, "file '"+k.Value+"'")
	}
	interim := strings.Join(sortedStrings, "\n")
	f, err := os.Create(w.filePath + "_new.txt")
	new_sorted := strings.TrimSpace(interim)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	_, err = fmt.Fprintf(f, "%s", new_sorted)
	if err != nil {
		log.Fatal(err)
	}
	Reduce(w.filePath+"_new.txt", w.targetPath, w.command, w.commandParamInputFile, w.commandParamOutputFile)
	fmt.Println("Reducer Done " + w.reducerNum)
}

func Map(path string, filenames []string, filename string) []KeyValue {
	kva := []KeyValue{}
	for _, w := range filenames {
		filePath := path + w
		temp := strings.Split(w, ".")[0]
		k, _ := strconv.Atoi(temp[len(filename):])
		kv := KeyValue{k, filePath}
		kva = append(kva, kv)
	}
	return kva
}

func Reduce(filename string, targetFile string, command string, commandParamInputFile string, commandParamOutputFile string) {
	param := strings.Split(commandParamInputFile, " ")
	param = append(param, filename)
	if commandParamOutputFile != "" {
		param2 := strings.Split(commandParamOutputFile, " ")
		param = append(param, param2...)
	}
	param = append(param, targetFile)
	//param = append(param, "--blocking")
	log.Println(param)
	cmd := exec.Command(command, param...)
	stdout, err := cmd.CombinedOutput()
	log.Println(string(stdout))
	HandleError(err)
}

func _init_map(obj map[string]interface{}) *Mapper {
	//log.Println(obj["mapNumber"].(float64))
	mapNumber, ok := obj["mapNumber"].(float64)
	HandleArgParsingCheck(ok, "mapNumber")
	totalReducer, ok := obj["totalReducer"].(float64)
	HandleArgParsingCheck(ok, "totalReducer")
	dirPath, ok := obj["dirPath"].(string)
	HandleArgParsingCheck(ok, "dirPath")
	bucketMax, ok := obj["bucketMax"].(float64)
	HandleArgParsingCheck(ok, "bucketMax")
	mediaPath, ok := obj["mediaPath"].(string)
	HandleArgParsingCheck(ok, "mediaPath")
	startFrame, ok := obj["startFrame"].(float64)
	HandleArgParsingCheck(ok, "startFrame")
	endFrame, ok := obj["endFrame"].(float64)
	HandleArgParsingCheck(ok, "endFrame")
	filename, ok := obj["filename"].(string)
	HandleArgParsingCheck(ok, "filename")
	w := Mapper{}
	w.filenames = GetAllFiles(int(startFrame), int(endFrame), mediaPath)
	//log.Println(w.filenames)
	w.numReducers = int(totalReducer)
	w.mapNumber = strconv.Itoa(int(mapNumber))
	w.dirPath = dirPath
	w.bucketMax = int(bucketMax)
	w.mediaPath = mediaPath
	w.filename = filename
	return &w
}

func _init_reduce(obj map[string]interface{}) *Reducer {
	dirPath, ok := obj["dirPath"].(string)
	HandleArgParsingCheck(ok, "dirPath")
	targetPath, ok := obj["targetPath"].(string)
	HandleArgParsingCheck(ok, "targetPath")
	reducerNum, ok := obj["reducerNum"].(float64)
	HandleArgParsingCheck(ok, "reducerNum")
	command, ok := obj["command"].(string)
	HandleArgParsingCheck(ok, "command")
	commandParamInputFile, ok := obj["commandParamInputFile"].(string)
	HandleArgParsingCheck(ok, "commandParamInputFile")
	commandParamOutputFile, ok := obj["commandParamOutputFile"].(string)
	HandleArgParsingCheck(ok, "commandParamOutputFile")
	filename, ok := obj["filename"].(string)
	HandleArgParsingCheck(ok, "filename")
	guid, ok := obj["guid"].(string)
	HandleArgParsingCheck(ok, "guid")
	w := Reducer{}
	w.guid = guid
	w.filePath = dirPath
	w.targetPath = targetPath
	w.reducerNum = strconv.Itoa(int(reducerNum))
	w.filePath = w.filePath + w.reducerNum
	w.filename = filename
	w.command = command
	w.commandParamInputFile = commandParamInputFile
	w.commandParamOutputFile = commandParamOutputFile
	w.targetPath = w.targetPath + w.filename + w.reducerNum + ".mp4"
	return &w
}

func PartitionToReducers(kva []KeyValue, w *Mapper) [][]KeyValue {
	kvas := make([][]KeyValue, w.numReducers)
	//log.Println(w.bucketMax)
	for _, kv := range kva {
		i := kv.Key
		v := i / (w.bucketMax)
		kvas[v] = append(kvas[v], kv)
	}
	return kvas
}

func WriteToJSONFile(w *Mapper, intermediate []KeyValue, reduceNum int) {
	path := w.dirPath
	log.Println("Creating outer folder: " + path)
	CreateDirectoryIfNotExist(path)
	filePath := path + strconv.Itoa(reduceNum)
	log.Println("Creating inner folder: " + filePath)
	CreateDirectoryIfNotExist(filePath)
	filename := filePath + "/" + strconv.Itoa(reduceNum) + "-" + w.mapNumber + ".txt"
	log.Println("Creating file: " + filename)
	file, _ := json.Marshal(intermediate)
	err := ioutil.WriteFile(filename, file, 0777)
	if err != nil {
		log.Println(err.Error())
	}
}

func GetAllFiles(start int, end int, path string) []string {
	log.Println(start)
	log.Println(end)
	files, err := ioutil.ReadDir(path)
	if err != nil {
		log.Fatal(err)
	}
	var fileNames []string
	for i, file := range files {

		if i >= start && i < end {
			log.Println(file.Name())
			fileNames = append(fileNames, file.Name())
		} else if i >= end {
			break
		}
	}
	return fileNames
}

func CreateDirectoryIfNotExist(path string) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		err := os.Mkdir(path, 0777)
		if err != nil {
			if !strings.Contains(string(err.Error()), "file exists") {
				log.Fatal("error: ", err)
			}
		}
	}
}

func HandleArgParsingCheck(ok bool, varName string) {
	if !ok {
		fmt.Println("Error while extracting " + varName + " from input")
		return
	}
}

func HandleError(err error) {
	if err != nil {
		log.Fatal(err)
		return
	}
}