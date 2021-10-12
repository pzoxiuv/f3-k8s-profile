package main

import (
	"flag"
	"fmt"
	"context"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

func main() {
	endpoint := flag.String("endpoint", "", "server endpoint url, not including scheme")
	bucket := flag.String("bucket", "", "bucket to create")
	accessKeyID := flag.String("accesskey","minio", "minio svc access key")
	secretAccessKey := flag.String("secretkey", "minio123", "minio svc secret key")
	useSSL := flag.Bool("usessl", false, "http=false, http=true")

	flag.Parse()
	
	// Initialize minio client object.
	minioClient, err := minio.New(*endpoint, &minio.Options{
		Creds: credentials.NewStaticV4(*accessKeyID, *secretAccessKey, ""),
		Secure: *useSSL,
	})
	if err != nil {
		fmt.Println(err)
		return
	}

	//log.Printf("%#v\n", minioClient)	// minioClient is now set up

	err = minioClient.MakeBucket(context.TODO(), *bucket, minio.MakeBucketOptions{})
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println("Successfully created", *bucket)
	
}