package main

import (
    "flag"
    "net"
    "os"
    "io"
    "time"
)

const (
    FNAME = "/mnt/ramdisk/f"
)

func handleConnection(conn net.Conn) {
	clientAddress := conn.RemoteAddr().String()
    fmt.Printf("Got conn from %v", clientAddress)

	file, err := os.Open(FNAME)
	if err != nil {
        //buf := make([]byte, 16*1024*1024)
        //w, err := io.CopyBuffer(conn, file, buf)
        w, err := io.Copy(conn, file)
        if err != nil {
            fmt.Println(err.Error())
        }
    }
    conn.Close()
}

func server() error {
	l, err := net.Listen("tcp", "0.0.0.0:9999")
	if err != nil{
        fmt.Println(err.Error())
        return
	}
	defer l.Close()

	for {
		conn, err := l.Accept()
		if err != nil{
            fmt.Println(err.Error())
			continue
		}
		go handleConnection(conn)
	}
}

func client() error {
    conn, err := net.DialTimeout("tcp", "kubes1", 1*time.Second)
    if err != nil {
        fmt.Println(err.Error());
    }

    if _, err := os.Stat(FNAME); errors.Is(err, os.IsNotExist(err) {
        os.Remove(FNAME)
    }

    fd, err := os.OpenFile(FNAME, os.O_APPEND | os.O_CREATE | os.O_WRONLY, 0644)
    if err != nil {
        return err
    }

    start := time.Now()
    //if w, err := io.CopyBuffer(f.fd, f.conn, buf); err != nil {
    if w, err := io.Copy(f.fd, f.conn); err != nil {
        fmt.Println(err.Error())
    }
    elapsed := time.Since(start).Seconds()
    fmt.Printf("Took %v seconds", elapsed)
}

func main() {
    var amServer bool
    
    flag.BoolVar(&amServer, "server", true, "")
    flag.Parse()

    if amServer {
        server()
    } else {
        client()
    }
}
