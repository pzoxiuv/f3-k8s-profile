#!/bin/bash

kubectl cp fuse/f3-fuse-driver dev-pod-1:/fuse/f3-fuse-driver
kubectl cp fuse/f3-fuse-driver dev-pod-2:/fuse/f3-fuse-driver

echo "fuse driver"

kubectl cp client-server/src/client/client.go dev-pod-1:/cs/src/client/client.go
kubectl cp client-server/src/server/server.go dev-pod-1:/cs/src/server/server.go

kubectl cp client-server/src/client/client.go dev-pod-2:/cs/src/client/client.go
kubectl cp client-server/src/server/server.go dev-pod-2:/cs/src/server/server.go
