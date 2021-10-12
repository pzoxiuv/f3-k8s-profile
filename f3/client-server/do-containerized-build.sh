#!/bin/sh

cd /workdir
mkdir -p build
cp -r src/client/client.go build
cp -r src/server/server.go build
cp -r src/fuse-stub/socketstub2.go build
cd build
go mod init main
go mod tidy
go build client.go
go build server.go
go build socketstub2.go
