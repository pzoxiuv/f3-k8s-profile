/*param-1: number of mappers/reducers (4)
param-2: folder path for utility (/home/rishsriv/go_wks/mr/util)
param-3: media path(/home/rishsriv/go_wks/mr/temp/)
param-4: filename (out)
param-5: command to run (ffmpeg)
param-6: parameter for command "-f concat -safe 0 -i" -> to concat files, "commandline" -> for command line (not yet implemented)
sudo ./master 10 10 "/home/rishsriv/go_wks/mr/util" "/home/rishsriv/go_wks/mr/temp"
param-7: Worker
*/

package main

import (
	//"bytes"
	"errors"
	"fmt"
	"log"
	"math"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"
	"encoding/hex"
	"math/rand"
)

//0->unallocated
//2->finsihed

type Master struct {
	mappers     map[string]string
	reducers    map[string]string
	rawfiles    []string
	numRawFiles int
	numMappers  int
	numReducers int
	dirPath     string
	mediaPath   string
	isFrame     int
	filename    string
	fsSeqId	    string 
}

var (
	command                string
	commandParamInputFile  string
	commandParamOutputFile string
	action                 string
)

func main() {
	start := time.Now()
	command = os.Args[5]
	commandParamInputFile = os.Args[6]
	commandParamOutputFile = os.Args[7]
	action = os.Args[8]
	Validate()
	//truncate utility directory
	DeleteNCreateUtilDir(os.Args[2])
	//call initialization function first time, identified by last param(0)
	m := _init(os.Args[1], 0)
	//this is a recursive call to merge
	UtilReducer(m)
	duration := time.Since(start)
	log.Println("Reducing Completed!!")
	log.Printf("Total Time to reduce: %f", duration.Seconds())
	//DeleteIntermediateFiles(m)
}

func UtilReducer(m *Master) {
	if m.numReducers < 1 {
		return
	}
	start := time.Now()
	TriggerMappers(m)
	m.numReducers=GetFileCount(m.dirPath)
	log.Println(m.numReducers)
	TriggerReducers(m)
	duration := time.Since(start)
	log.Printf("Time to reduce: %f", duration.Seconds())
	if(m.numReducers!=1){
		start = time.Now()
		m.numMappers = 1
		m.numReducers = 1
		m = _init(strconv.Itoa(m.numMappers), 1)
		TriggerMappers(m)
		TriggerReducers(m)
		duration = time.Since(start)
		log.Printf("Time to redce 2: %f", duration.Seconds())
	}
}

func _init(numWorkers string, num int) *Master {
	m := Master{}
	var err error
	m.mappers = make(map[string]string)
	m.reducers = make(map[string]string)
	if num == 0 {
		m.mediaPath = os.Args[3]
		m.dirPath = os.Args[2] + "/out/"
		CreateDirIfNotExist(m.mediaPath)
		CreateDirIfNotExist(m.dirPath)
		m.isFrame = 1
	} else {
		m.mediaPath = os.Args[2] + "/temp-" + numWorkers + "/"
		m.dirPath = os.Args[2] + "/out-" + numWorkers + "/"
		CreateDirIfNotExist(m.mediaPath)
		CreateDirIfNotExist(m.dirPath)
		m.isFrame = 0
	}
	log.Println(m.mediaPath)
	m.numRawFiles = GetFileCount(m.mediaPath)
	m.numMappers, err = strconv.Atoi(numWorkers)
	m.filename = os.Args[4]
	m.fsSeqId = os.Args[9]
	if err != nil {
		fmt.Println(err)
	}
	for i := 0; i < m.numMappers; i++ {
		m.mappers[strconv.Itoa(i)] = "0"
	}
	m.numReducers, err = strconv.Atoi(numWorkers)
	for i := 0; i < m.numReducers; i++ {
		m.reducers[strconv.Itoa(i)] = "0"
	}
	if err != nil {
		fmt.Println(err)
	}
	log.Println(m.numRawFiles)
	return &m
}

func TriggerMappers(m *Master) {
	var wg sync.WaitGroup
	typeOfJob := "Map"
	buckets := m.numMappers
	startingBucketSize := int(math.Floor(float64(m.numRawFiles)/float64(m.numMappers))) + 1
	endingBucketSize := int(math.Floor(float64(m.numRawFiles) / float64(m.numMappers)))
	startingBucket := m.numRawFiles % m.numMappers
	log.Println(startingBucketSize)
	log.Println(endingBucketSize)
	log.Println(startingBucket)
	start := 0
	for i := 0; i < buckets; i++ {
		wg.Add(1)
		if i < startingBucket {
			go TrackMapper(m, start, start+startingBucketSize, typeOfJob, i, &wg)
			start = start + startingBucketSize
		} else {
			go TrackMapper(m, start, start+endingBucketSize, typeOfJob, i, &wg)
			start = start + endingBucketSize
		}
	}
	wg.Wait()
}

func TriggerReducers(m *Master) {
	var wg sync.WaitGroup
	typeOfJob := "Reduce"
	start := time.Now()
	for i := 0; i < m.numReducers; i++ {
		wg.Add(1)
		go TrackReducer(m, i, typeOfJob, &wg)
	}
	wg.Wait()
	duration := time.Since(start)
	log.Printf("Total time to just reduce: %f", duration.Seconds())
}

func TrackMapper(m *Master, start int, end int, typeOfJob string, mapNumber int, wg *sync.WaitGroup) {
	defer wg.Done()
	var param []string
	bucketMax := int(math.Ceil(float64(m.numRawFiles) / float64(m.numReducers)))
	if m.isFrame == 1 {
		bucketMax += 1
	}
	param = append(param, "action")
	param = append(param, "invoke")
	param = append(param, action)
	param = append(param, "--result")
	param = append(param, "--param")
	param = append(param, "type")
	param = append(param, typeOfJob)
	param = append(param, "--param")
	param = append(param, "mapNumber")
	param = append(param, strconv.Itoa(mapNumber))
	param = append(param, "--param")
	param = append(param, "totalReducer")
	param = append(param, strconv.Itoa(m.numReducers))
	param = append(param, "--param")
	param = append(param, "dirPath")
	param = append(param, m.dirPath)
	param = append(param, "--param")
	param = append(param, "bucketMax")
	param = append(param, strconv.Itoa(bucketMax))
	param = append(param, "--param")
	param = append(param, "mediaPath")
	param = append(param, m.mediaPath)
	param = append(param, "--param")
	param = append(param, "startFrame")
	param = append(param, strconv.Itoa(start))
	param = append(param, "--param")
	param = append(param, "endFrame")
	param = append(param, strconv.Itoa(end))
	param = append(param, "--param")
	param = append(param, "filename")
	param = append(param, m.filename)
	param = append(param, "--param")
	param = append(param, "f3SeqId")
	param = append(param, m.fsSeqId)
	param = append(param, "-i")
	log.Println(param)
	cmd := exec.Command("wsk", param...)
	stdout, err := cmd.Output()
	if err != nil {
		log.Fatal(err.Error())
		return
	}
	if !strings.Contains(string(stdout), "Success") {
		log.Fatal("error: ", string(stdout))
	}
	log.Println(string(stdout))
	m.mappers[strconv.Itoa(mapNumber)] = "2"
}

func TrackReducer(m *Master, reducerNum int, typeOfJob string, wg *sync.WaitGroup) {
	s1 := time.Now()
	b := make([]byte, 4)
	rand.Read(b)
	guid := hex.EncodeToString(b)
	defer wg.Done()
	var param []string
	var nextReducer int
	dirPath := m.dirPath
	if m.numReducers == 1 {
		nextReducer = 0
	} else {
		nextReducer = 1
	}
	targetPath := os.Args[2] + "/temp-" + strconv.Itoa(nextReducer) + "/"
	CreateDirIfNotExist(targetPath)
	param = append(param, "action")
	param = append(param, "invoke")
	param = append(param, action)
	param = append(param, "--result")
	param = append(param, "--param")
	param = append(param, "type")
	param = append(param, typeOfJob)
	param = append(param, "--param")
	param = append(param, "dirPath")
	param = append(param, dirPath)
	param = append(param, "--param")
	param = append(param, "targetPath")
	param = append(param, targetPath)
	param = append(param, "--param")
	param = append(param, "reducerNum")
	param = append(param, strconv.Itoa(reducerNum))
	param = append(param, "--param")
	param = append(param, "filename")
	param = append(param, m.filename)
	param = append(param, "--param")
	param = append(param, "command")
	param = append(param, command)
	param = append(param, "--param")
	param = append(param, "commandParamInputFile")
	param = append(param, commandParamInputFile)
	param = append(param, "--param")
	param = append(param, "commandParamOutputFile")
	param = append(param, commandParamOutputFile)
	param = append(param, "--param")
	param = append(param, "guid")
	param = append(param, guid)
	param = append(param, "--param")
	param = append(param, "f3SeqId")
	param = append(param, m.fsSeqId)
	param = append(param, "-i")
	//param = append(param, "--blocking")
	log.Println(param)
	//var stdout1 bytes.Buffer
	//var stderr bytes.Buffer
	cmd := exec.Command("wsk", param...)
	//cmd.Stdout = &stdout1
	//cmd.Stderr = &stderr
	//err := cmd.Run()
	stdout, _ := cmd.CombinedOutput()
	//log.Println(stdout1.String())
	//log.Println(stderr.String())
	//log.Println(err)
	//stdout:=stderr.String()
	/*if(err!=nil){
		log.Println("Got an error here")
		//stdout1:=err
		if exiterr, ok := err.(*exec.ExitError); ok{
			log.Println(cmd.)
			log.Println(cmd.Stderr)
		}
	}*/
	d1 := time.Since(s1)
	log.Println("Time to reduce-1 %f", d1.Seconds())
	s2 := time.Now()
	//if err!=nil{
		//log.Println("Error")
		//log.Println(err.Error())
	//}
	isSuccess := false
	if !strings.Contains(string(stdout), "Success") {
		log.Println("Printing stdout")
		log.Println(string(stdout))
		str := strings.Split(string(stdout), " ")
		log.Println("guid is " + guid)
		//log.Println(len(str[len(str)-1]))
		counter := 0
		for counter<=6000 {
			if pollAction(str[len(str)-1], guid)==true{
				isSuccess=true
				break;
			}
			time.Sleep(10*time.Millisecond)
			counter=counter+1
		}
	}
	//log.Println("Value")
	if (strings.Contains(string(stdout), "Success") || isSuccess==true){
		log.Println("in last check")
		//log.Println(string(stdout))
		//log.Println(isSuccess)
		m.reducers[strconv.Itoa(reducerNum)] = "2"
	}else{
		log.Fatal("wsk action failed, check logs!!")
	}
	d2 := time.Since(s2)
	log.Println("Time to reduce-2: %f", d2.Seconds())
}

func pollAction(id string, guid string) bool{
	//log.Println("In wsk logs")
	id = strings.TrimSpace(id)
	//log.Println(len(id))
	cmd := exec.Command("wsk", "activation", "logs", id, "-i")
	stdout, _ := cmd.CombinedOutput()
	//if err != nil{
	//	log.Println("Error in wsk logs")
	//	log.Println(string(stdout))
	//	log.Println(err.Error())
	//}
	if strings.Contains(string(stdout), "Successfully executed "+guid){
		//log.Println(string(stdout))
		return true
	} else{
		return false
	}
}
func DeleteIntermediateFiles(m *Master) {
	for i := 0; i < m.numReducers; i++ {
		err := os.RemoveAll(strconv.Itoa(i))
		if err != nil {
			log.Fatal(err)
		}
	}
}

func GetFileCount(path string) int {
	f, err := os.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	files, err := f.Readdir(-1)
	f.Close()
	if err != nil {
		log.Fatal(err)
	}
	return len(files)
}

func DeleteNCreateUtilDir(path string) {
	err := os.RemoveAll(path)
	if err != nil {
		log.Fatal(err)
	}
	CreateDirIfNotExist(path)
}

func CreateDirIfNotExist(path string) {
	if _, err := os.Stat(path); errors.Is(err, os.ErrNotExist) {
		err := os.Mkdir(path, os.ModePerm)
		if err != nil {
			log.Println(err)
		}
	}
}

func Validate() bool {
	if len(os.Args) < 5 {
		fmt.Fprintf(os.Stderr, "Input parameters are missing\n")
		os.Exit(1)
		return false
	}
	return true
}
