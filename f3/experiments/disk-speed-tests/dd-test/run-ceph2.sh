#!/bin/bash

if [ -f lock ]; then
    echo "Already running?"
    exit
fi

touch lock

COUNT=$(( $1 / 4 ))

ITER=2

MYDIR=`dirname $0`

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

for i in `seq 0 $ITER`; do 

    kubectl apply -f /local/repository/f3/experiments/f3-only-pvc.yaml
    kubectl apply -f /local/repository/f3/experiments/f3-pod-kubes1.yaml
    kubectl apply -f /local/repository/f3/experiments/f3-pod-kubes3.yaml
    kubectl wait --for=condition=ready pod f3-testing1-pod-kubes1 -nopenwhisk --timeout=200s
    kubectl wait --for=condition=ready pod f3-testing1-pod-kubes3 -nopenwhisk --timeout=200s
    bash -c "cd /local/repository/f3/experiments/micro-benchmark/; ./copy-files-f3.sh"

    echo "BBB,`date +%s`"
    timeout 600 /local/repository/f3/experiments/micro-benchmark/run-nostats-f3only.sh /var/cephfs/f$i $1 $i >> $MYDIR/e2e-ceph-$1$2
    echo "CCC,`date +%s`"

    kubectl delete -f /local/repository/f3/experiments/f3-pod-kubes1.yaml
    kubectl delete -f /local/repository/f3/experiments/f3-pod-kubes3.yaml
    kubectl delete -f /local/repository/f3/experiments/f3-only-pvc.yaml

    kubectl apply -f /local/repository/f3/experiments/f3-only-pvc.yaml
    kubectl apply -f /local/repository/f3/experiments/f3-pod-kubes1.yaml
    kubectl apply -f /local/repository/f3/experiments/f3-pod-kubes3.yaml
    kubectl wait --for=condition=ready pod f3-testing1-pod-kubes1 -nopenwhisk --timeout=200s
    kubectl wait --for=condition=ready pod f3-testing1-pod-kubes3 -nopenwhisk --timeout=200s

    {
    echo "DDD,`date +%s`"
    /usr/bin/time -f "TOTAL,%e,$i" kubectl exec -ti f3-testing1-pod-kubes1 -nopenwhisk -- bash -c "dd if=/dev/zero of=/var/cephfs/f bs=4M count=$COUNT; sync"
    echo "EEE,`date +%s`"
    } >> $MYDIR/write-ceph-$1$2 2>&1

    {
    echo "FFF,`date +%s`"
    /usr/bin/time -f "TOTAL,%e,$i" kubectl exec -ti f3-testing1-pod-kubes1 -nopenwhisk -- bash -c "dd if=/var/cephfs/f of=/dev/null bs=4M count=$COUNT; sync"
    echo "GGG,`date +%s`"
    } >> $MYDIR/read-ceph-$1$2 2>&1

    kubectl delete -f /local/repository/f3/experiments/f3-pod-kubes1.yaml
    kubectl delete -f /local/repository/f3/experiments/f3-pod-kubes3.yaml
    kubectl delete -f /local/repository/f3/experiments/f3-only-pvc.yaml

done

rm lock
