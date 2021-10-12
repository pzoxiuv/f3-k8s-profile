package main

import (
	"io"
	"strings"
	"strconv"
	"bufio"
	"flag"
	"fmt"
	"net"
	"time"
	"os"
	"path"
	"sync"
)

const (
	connType	= "tcp"
	//BLOCKSIZE	= 1 * 1024 * 1024
	BLOCKSIZE = 1
)

type File struct {
	fname	string
	pos	int64
	conn	net.Conn
	fd	*os.File
	c	chan int64
	l	sync.Mutex
}

var filesLock sync.Mutex
var files map[string]File
var tempDir string

func openConnection(server, fname string) {
	conn, err := net.DialTimeout("tcp", server, 1*time.Second)
	if err != nil {
		fmt.Println(err.Error())
		return
	}
	fd, err := os.OpenFile(path.Join(tempDir, fname), os.O_APPEND | os.O_CREATE | os.O_WRONLY, 0644)
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	stat, err := fd.Stat()
	if err != nil {
		fmt.Println(err.Error())
		return
	}
	fmt.Printf("File pos: %v\n", stat.Size())

	filesLock.Lock()
	files[fname] = File{fname, stat.Size(), conn, fd, make(chan int64), sync.Mutex{}}
	filesLock.Unlock()

	//go connHandler(files[fname])
}

func downloadMore(f File, endByte int64) {
	// Round up to nearest block size
	if (endByte - f.pos) % BLOCKSIZE != 0 {
		endByte = BLOCKSIZE - ((endByte - f.pos) % BLOCKSIZE) + (endByte - f.pos)
	}

	fmt.Printf("Reading %v bytes\n", endByte - f.pos)
	if w, err := io.CopyN(f.fd, f.conn, endByte - f.pos); err != nil {
		f.pos += w
		fmt.Println(err.Error())
		return
	}
	// We can only be here if there was no err, so must have read everything
	fmt.Printf("Read %v bytes\n", endByte - f.pos)
}

func fuseReq(line string) {
	fmt.Println(line)
	arr := strings.Split(strings.TrimRight(line, "\n"), ",")
	fname := strings.TrimSpace(arr[0])
	endByte, err := strconv.ParseInt(arr[1], 10, 64)
	if err != nil {
		fmt.Println("!!! 1", err.Error())
		return
	}

	if f, exists := files[fname]; !exists {
		fmt.Println("!!! 2")
		return
	} else {
		if endByte > f.pos {
			f.l.Lock()
			// Maybe by the time we got the lock we downloaded the part we want?
			if endByte <= f.pos {
				f.l.Unlock()
				return
			}
			downloadMore(f, endByte)
			f.l.Unlock()
		}
	}
}

func main() {
	//socket_file := flag.String("socket-file", "/f3/fuse-client.sock", "string")
	flag.StringVar(&tempDir, "temp-dir", "client-tempdir", "string")
	flag.Parse()

	files = make(map[string]File)

	openConnection("localhost:9999", "testing")

	reader := bufio.NewReader(os.Stdin)
	for {
		text, _ := reader.ReadString('\n')
		fuseReq(text)
	}
}
