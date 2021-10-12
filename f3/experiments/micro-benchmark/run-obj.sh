#!/bin/bash

#FILESIZE=$(( $2 * 1024 * 1024 ))

ENDPOINT=$(kubectl get endpoints minio-service | tail -n1 | awk '{print $2}')
BUCKET=testbucket
OBJECT=testobj

before1=$(date +%s)
kubectl exec testing1-pod-kubes1 -nopenwhisk -- /obj-writer -endpoint $ENDPOINT -bucket $BUCKET -object $OBJECT -size $1
after1=$(date +%s)
echo "$(( $after1 - $before1 )) s total"

before2=$(date +%s)
kubectl exec testing1-pod-kubes3 -nopenwhisk -- /obj-reader -endpoint $ENDPOINT -bucket $BUCKET -object $OBJECT
after2=$(date +%s)
echo "$(( $after2 - $before2 )) s total"
echo "$(( $after2 - $before1 )) s minio-obj total $1 YYY"
