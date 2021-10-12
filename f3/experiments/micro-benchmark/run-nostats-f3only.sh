#!/bin/bash

FILESIZE=$(( $2 * 1024 * 1024 ))
#FILESIZE=$(( $2 * 1024 ))

SC=`echo $1 | cut -d/ -f3`

echo "date,`date +%s`"

kubectl exec f3-testing1-pod-kubes1 -nopenwhisk -- /vmtouch -q -e $1

before1=$(date +%s)
kubectl exec f3-testing1-pod-kubes1 -nopenwhisk -- /writer $1 $FILESIZE
after1=$(date +%s)
write_time=$(( $after1 - $before1 ))
#echo "$(( $after1 - $before1 ))"

kubectl exec f3-testing1-pod-kubes3 -nopenwhisk -- ls -lh /var/f3 >/dev/null
kubectl exec f3-testing1-pod-kubes3 -nopenwhisk -- stat $1 >/dev/null
kubectl exec f3-testing1-pod-kubes3 -nopenwhisk -- stat $1 >/dev/null
kubectl exec f3-testing1-pod-kubes3 -nopenwhisk -- ls -lh /var/f3 >/dev/null

before2=$(date +%s)
kubectl exec f3-testing1-pod-kubes3 -nopenwhisk -- /reader $1
after2=$(date +%s)
read_time=$(( $after2 - $before2 ))
#echo $before2 $after2
#echo "read,$(( $after2 - $before2 ))"
#echo "$(( $write_time + $read_time )) s total $1 YYY"
echo "$(( $after1 - $before1 )),$(( $after2 - $before2 )),$(( $write_time + $read_time )),$3,YYY"

kubectl exec f3-testing1-pod-kubes1 -nopenwhisk -- rm $1
sudo -u amerenst ssh node-1 sudo rm -rf /mnt/local-cache/tempdir/*
sudo -u amerenst ssh node-2 sudo rm -rf /mnt/local-cache/tempdir/*
