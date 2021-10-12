#!/bin/bash

FILESIZE=$(( $2 * 1024 * 1024 ))

kubectl exec testing1-pod-kubes1 -nopenwhisk -- /vmtouch -q -e $1
kubectl exec testing1-pod-kubes3 -nopenwhisk -- /vmtouch -q -e $1
before1=$(date +%s)
kubectl exec testing1-pod-kubes1 -nopenwhisk -- /writer $1 $FILESIZE
after1=$(date +%s)
echo "$(( $after1 - $before1 )) s total"
kubectl exec testing1-pod-kubes3 -nopenwhisk -- ls -lh /var/f3
kubectl exec testing1-pod-kubes3 -nopenwhisk -- stat $1
kubectl exec testing1-pod-kubes3 -nopenwhisk -- stat $1
kubectl exec testing1-pod-kubes3 -nopenwhisk -- ls -lh /var/f3
#sleep 5

before2=$(date +%s)
kubectl exec testing1-pod-kubes3 -nopenwhisk -- /reader $1
after2=$(date +%s)
echo "$(( $after2 - $before2 )) s total"
echo "$(( $after2 - $before1 )) s total $1 YYY"
