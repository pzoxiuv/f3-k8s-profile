#!/bin/bash

FILESIZE=$(( $2 * 1024 * 1024 ))

kubectl exec testing1-pod-kubes1 -nopenwhisk -- /vmtouch -q -e $1
#kubectl exec testing1-pod-kubes1 -nopenwhisk -- touch $1
before=$(date +%s)
kubectl exec testing1-pod-kubes1 -nopenwhisk -- bash -c "/writer $1 $FILESIZE; touch $1.done" &
#sleep 2
kubectl exec testing1-pod-kubes3 -nopenwhisk -- /consume-discard.py $1
wait
after=$(date +%s)
echo "$(( $after - $before )) s total YYY"
