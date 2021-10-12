package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

var buf = make([]byte, 4*1024*1024)

func main() {
	endpoint := flag.String("endpoint", "", "server endpoint url, not including scheme")
	bucket := flag.String("bucket", "", "bucket to read object from")
	object := flag.String("object", "", "object to read")
	accessKeyID := flag.String("accesskey", "minio", "minio svc access key")
	secretAccessKey := flag.String("secretkey", "minio123", "minio svc secret key")
	useSSL := flag.Bool("usessl", false, "http=false, https=true")

	flag.Parse()

	// Initialize minio client object.
	minioClient, err := minio.New(*endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(*accessKeyID, *secretAccessKey, ""),
		Secure: *useSSL,
	})
	if err != nil {
		fmt.Println(err)
		return
	}

	//log.Printf("%#v\n", minioClient)	// minioClient is now set up

	a := time.Now()
	// The GetObject method returns a *minio.Object. This implements io.Reader, io.Seeker, io.ReaderAt and io.Closer
	// interfaces for an HTTP stream. An object represents an open object.
	obj, err := minioClient.GetObject(context.TODO(), *bucket, *object, minio.GetObjectOptions{})
	if err != nil {
		fmt.Println(err)
		return
	}
	b := time.Now()

	readbytes := 0
	for {
		n, err := obj.Read(buf)
		if err == io.EOF {
			//fmt.Println(string(buf[:n]))
			readbytes += n
			break
		}
		if err != nil {
			fmt.Println(err)
			return
		}
		if n > 0 {
			//fmt.Println(string(buf[:n]))
		}
		readbytes += n
	}
	c := time.Now()

	// Close http response body, ending connection with the server. This *minio.Object cannot be used again to read the object from the server
	err = obj.Close()
	if err != nil {
		fmt.Println(err)
		return
	}
	d := time.Now()

	opentime := b.Sub(a)
	readtime := c.Sub(b)
	closetime := d.Sub(c)

	fmt.Println("Open time: ", opentime)
	fmt.Println("Read time: ", readtime)
	fmt.Println("Close time: ", closetime)
	fmt.Println("Total time: ", opentime+readtime+closetime)
	fmt.Println("Read ", readbytes, " bytes")
}
