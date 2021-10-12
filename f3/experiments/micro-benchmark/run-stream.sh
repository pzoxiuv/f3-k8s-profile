#!/bin/bash

FILESIZE=$(( $2 * 1024 * 1024 ))

kubectl exec testing1-pod-kubes1 -nopenwhisk -- /vmtouch -q -e $1
#kubectl exec testing1-pod-kubes1 -nopenwhisk -- touch $1
before=$(date +%s)
kubectl exec testing1-pod-kubes1 -nopenwhisk -- /writer $1 $FILESIZE &
sleep 2
kubectl exec testing1-pod-kubes3 -nopenwhisk -- /reader $1
wait
after=$(date +%s)
echo "$(( $after - $before )) s total YYY"
