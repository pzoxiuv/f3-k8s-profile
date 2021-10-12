package main

import (
    "io"
	//"bytes"
	"context"
	//_ "embed"
	"flag"
	"fmt"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

//go:embed rand.bin
//var rand_bin []byte

type RepReader struct {
    data []byte
    readIndex int64
    desiredBytes int64
}

func (r *RepReader) Read(p []byte) (int, error) {
    if r.readIndex >= int64(len(r.data)) {
        r.readIndex = 0
    }

    end := int64(len(r.data))
    if r.desiredBytes < (end - r.readIndex) {
        end = r.readIndex + r.desiredBytes
    }

    n := copy(p, r.data[r.readIndex:end])
    r.readIndex += int64(n)
    r.desiredBytes -= int64(n)

    //fmt.Printf("Read %v %v %v bytes\n", n, r.readIndex, r.desiredBytes)

    if r.desiredBytes <= 0 {
        return n, io.EOF
    }

    return n, nil
}

func main() {
	endpoint := flag.String("endpoint", "", "server endpoint url, not including scheme")
	bucket := flag.String("bucket", "", "bucket to write object to")
	object := flag.String("object", "", "name of object to create")
	accessKeyID := flag.String("accesskey", "minio", "minio svc access key")
	secretAccessKey := flag.String("secretkey", "minio123", "minio svc secret key")
	useSSL := flag.Bool("usessl", false, "http=false, http=true")
    size := flag.Int64("size", 5000, "size in MB")

	flag.Parse()

    rand_bin, err := Asset("rand.bin")
    if err != nil {
		fmt.Println(err)
		return
    }

    *size *= 1024 * 1024
    r := &RepReader{rand_bin, 0, *size}

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
	//uploadInfo, err := minioClient.PutObject(context.TODO(), *bucket, *object, bytes.NewReader(rand_bin), int64(len(rand_bin)), minio.PutObjectOptions{})
	uploadInfo, err := minioClient.PutObject(context.TODO(), *bucket, *object, r, *size, minio.PutObjectOptions{})
	if err != nil {
		fmt.Println(err)
		return
	}
	b := time.Now()
	writetime := b.Sub(a)

	fmt.Println("Write time: ", writetime)
	fmt.Println("Wrote ", uploadInfo.Size, " bytes")
}
