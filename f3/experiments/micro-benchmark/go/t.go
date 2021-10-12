package main

import (
    "io"
	"fmt"
    "strings"
)

//go:embed rand.bin
//var rand_bin []byte
    
type Reader struct {
    data []byte
    readIndex int64
    desiredBytes int64
}

func (r *Reader) Read(p []byte) (int, error) {
    if r.readIndex >= int64(len(r.data)) {
        r.readIndex = 0
    }

    end := int64(len(r.data))
    if r.desiredBytes < end {
        end = r.desiredBytes
    }

    n := copy(p, r.data[r.readIndex:end])
    r.readIndex += int64(n)
    r.desiredBytes -= int64(n)

    if r.desiredBytes <= 0 {
        return n, io.EOF
    }

    return n, nil
}

func main() {
    b := []byte("12345")

    r := &Reader{b, 0, 20}

    buf := new(strings.Builder)
    io.Copy(buf, r)
    fmt.Println(buf.String())

}
