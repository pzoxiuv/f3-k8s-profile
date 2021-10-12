#!/bin/bash

kubectl cp /home/alex/f3/client-server/client dev-pod-1:/client
kubectl cp /home/alex/f3/client-server/server dev-pod-1:/server

kubectl cp /home/alex/f3/client-server/client dev-pod-2:/client
kubectl cp /home/alex/f3/client-server/server dev-pod-2:/server

kubectl cp /home/alex/f3/fuse/f3-fuse-driver dev-pod-1:/f3-fuse-driver
kubectl cp /home/alex/f3/fuse/f3-fuse-driver dev-pod-2:/f3-fuse-driver

kubectl exec dev-pod-1 -- mkdir -p /tmp/tempdir
kubectl exec dev-pod-2 -- mkdir -p /tmp/tempdir

kubectl exec dev-pod-1 -- mkdir -p /var/workdir
kubectl exec dev-pod-2 -- mkdir -p /var/workdir

kubectl exec dev-pod-1 -- bash -c "/client -socket-file /client.sock -temp-dir /tmp/tempdir >/client.out 2>&1" &
kubectl exec dev-pod-2 -- bash -c "/client -socket-file /client.sock -temp-dir /tmp/tempdir >/client.out 2>&1" &

kubectl exec dev-pod-1 -- bash -c "/server -temp-dir /tmp/tempdir >/server.out 2>&1" &
kubectl exec dev-pod-2 -- bash -c "/server -temp-dir /tmp/tempdir >/server.out 2>&1" &

kubectl exec dev-pod-1 --  bash -c "/f3-fuse-driver --address kubes1:9999 -s /client.sock --nocache --debug --idroot /tmp/tempdir /var/data /var/workdir >/driver.out 2>&1" &
kubectl exec dev-pod-2 -- bash -c "/f3-fuse-driver --address kubes3:9999 -s /client.sock --nocache --debug --idroot /tmp/tempdir /var/data /var/workdir >/driver.out 2>&1" &
