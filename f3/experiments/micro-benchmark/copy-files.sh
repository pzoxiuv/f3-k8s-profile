#!/bin/bash

kubectl cp -nopenwhisk writer testing1-pod-kubes1:/writer
kubectl cp -nopenwhisk writer testing1-pod-kubes3:/writer
kubectl cp -nopenwhisk reader testing1-pod-kubes1:/reader
kubectl cp -nopenwhisk reader testing1-pod-kubes3:/reader
kubectl cp -nopenwhisk writer-many testing1-pod-kubes1:/writer-many
kubectl cp -nopenwhisk writer-many testing1-pod-kubes3:/writer-many
kubectl cp -nopenwhisk reader-many testing1-pod-kubes1:/reader-many
kubectl cp -nopenwhisk reader-many testing1-pod-kubes3:/reader-many
kubectl cp -nopenwhisk ../../utils/ow-run testing1-pod-kubes1:/ow-run
kubectl cp -nopenwhisk ../ffmpeg/setup.sh testing1-pod-kubes1:/setup.sh
kubectl cp -nopenwhisk ~/vmtouch/vmtouch testing1-pod-kubes1:/vmtouch
kubectl cp -nopenwhisk ~/vmtouch/vmtouch testing1-pod-kubes3:/vmtouch

kubectl cp -nopenwhisk consume.py testing1-pod-kubes1:/consume.py
kubectl cp -nopenwhisk consume.py testing1-pod-kubes3:/consume.py
kubectl cp -nopenwhisk consume-discard.py testing1-pod-kubes1:/consume-discard.py
kubectl cp -nopenwhisk consume-discard.py testing1-pod-kubes3:/consume-discard.py

kubectl cp -nopenwhisk go/obj-writer testing1-pod-kubes1:/obj-writer
kubectl cp -nopenwhisk go/obj-writer testing1-pod-kubes3:/obj-writer
kubectl cp -nopenwhisk go/obj-writer testing1-pod-kubes1:/obj-reader
kubectl cp -nopenwhisk go/obj-writer testing1-pod-kubes3:/obj-reader
kubectl cp -nopenwhisk go/makebucket testing1-pod-kubes1:/makebucket
kubectl cp -nopenwhisk go/makebucket testing1-pod-kubes3:/makebucket

kubectl exec -nopenwhisk testing1-pod-kubes1 -- yum install -y python3 time fio &
kubectl exec -nopenwhisk testing1-pod-kubes3 -- yum install -y python3 time fio &

kubectl exec -nopenwhisk testing1-pod-kubes1 -- ln -s /var/f3 /var/f3-nonid
kubectl exec -nopenwhisk testing1-pod-kubes3 -- ln -s /var/f3 /var/f3-nonid
kubectl exec -nopenwhisk testing1-pod-kubes1 -- ln -s /var/f3 /var/f3-ramdisk-nonid
kubectl exec -nopenwhisk testing1-pod-kubes3 -- ln -s /var/f3 /var/f3-ramdisk-nonid
kubectl exec -nopenwhisk testing1-pod-kubes1 -- ln -s /var/f3 /var/f3-ramdisk
kubectl exec -nopenwhisk testing1-pod-kubes3 -- ln -s /var/f3 /var/f3-ramdisk

wait
