obj-writer: obj-writer.go
	go build obj-writer.go bindata.go

obj-reader: obj-reader.go
	go build obj-reader.go

copy: obj-writer obj-reader
	kubectl cp -nopenwhisk obj-writer testing1-pod-kubes1:/obj-writer
	kubectl cp -nopenwhisk obj-reader testing1-pod-kubes1:/obj-reader
	kubectl cp -nopenwhisk obj-writer testing1-pod-kubes3:/obj-writer
	kubectl cp -nopenwhisk obj-reader testing1-pod-kubes3:/obj-reader
