#!/bin/bash

if [ -f lock ]; then
    echo "Already running?"
    exit
fi

touch lock

COUNT=$(( $1 / 4 ))

ITER=0

MYDIR=`dirname $0`

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

for i in `seq 0 $ITER`; do 

    kubectl apply -f /local/repository/f3/experiments/f3-only-pvc.yaml
    kubectl apply -f /local/repository/f3/experiments/f3-pod-kubes1.yaml
    kubectl apply -f /local/repository/f3/experiments/f3-pod-kubes3.yaml
    kubectl wait --for=condition=ready pod f3-testing1-pod-kubes1 -nopenwhisk --timeout=200s
    kubectl wait --for=condition=ready pod f3-testing1-pod-kubes3 -nopenwhisk --timeout=200s
    bash -c "cd /local/repository/f3/experiments/micro-benchmark/; ./copy-files-f3.sh"

    timeout 600 /local/repository/f3/experiments/micro-benchmark/run-nostats-f3only.sh /var/f3/f$i.id $1 $i >> $MYDIR/e2e-f3-$1$2

    kubectl delete -f /local/repository/f3/experiments/f3-pod-kubes1.yaml
    kubectl delete -f /local/repository/f3/experiments/f3-pod-kubes3.yaml
    kubectl delete -f /local/repository/f3/experiments/f3-only-pvc.yaml
    #kubectl rollout restart ds csi-f3-node
    #kubectl rollout status ds/csi-f3-node --timeout=300s
	kubectl delete pod `kubectl get pod -lapp=csi-f3-node -owide --field-selector spec.nodeName=node-1 --no-headers -o custom-columns=":metadata.name"`
    kubectl delete pod `kubectl get pod -lapp=csi-f3-node -owide --field-selector spec.nodeName=node-2 --no-headers -o custom-columns=":metadata.name"`
    kubectl wait --for=condition=ready pod `kubectl get pod -lapp=csi-f3-node -owide --field-selector spec.nodeName=node-1 --no-headers -o custom-columns=":metadata.name"` --timeout=200s
    kubectl wait --for=condition=ready pod `kubectl get pod -lapp=csi-f3-node -owide --field-selector spec.nodeName=node-2 --no-headers -o custom-columns=":metadata.name"` --timeout=200s
done

#for i in `seq 0 $ITER`; do
#    {
#    date
#    echo "AAA" `date +%s`
#
#    sudo -u amerenst ssh node-1 sudo /local/repository/f3/experiments/disk-speed-tests/dd-test/do-write-test.sh $i $COUNT
#
#    echo "---"
#    } >> $MYDIR/write-f3-$1$2 2>&1
#
#    {
#    date
#    echo "AAA" `date +%s`
#
#    sudo -u amerenst ssh node-1 sudo /local/repository/f3/experiments/disk-speed-tests/dd-test/do-write-direct-test.sh $i $COUNT
#
#    echo "---"
#    } >> $MYDIR/write-direct-f3-$1$2 2>&1
#
#    {
#    date
#    echo "AAA" `date +%s`
#
#    sudo -u amerenst ssh node-1 sudo /local/repository/f3/experiments/disk-speed-tests/dd-test/do-read-test.sh $i $COUNT
#
#    echo "---"
#    } >> $MYDIR/read-f3-$1$2 2>&1
#
#    {
#    date
#    echo "AAA" `date +%s`
#
#    sudo -u amerenst ssh node-1 sudo /local/repository/f3/experiments/disk-speed-tests/dd-test/do-read-direct-test.sh $i $COUNT
#
#    echo "---"
#    } >> $MYDIR/read-direct-f3-$1$2 2>&1
##
###    {
###    date
###    echo "AAA" `date +%s`
###
###    sudo -u amerenst sudo -u amerenst ssh kubes3 iperf -c 130.245.126.249 -n $1M
###
###    echo "---"
###    } >> /local/repository/f3/experiments/disk-speed-tests/dd-test/iperf-k3-k1-1500-limit-1500-res-$1 2>&1
###
###    {
###    date
###    echo "AAA" `date +%s`
###
###    iperf -c 10.245.126.125 -n $1M
###
###    echo "---"
###    } >> /local/repository/f3/experiments/disk-speed-tests/dd-test/iperf-k1-freenas-1500-limit-1500-res-$1 2>&1
#
#done

#for i in `seq 0 $ITER`; do 
#    timeout 600 sudo -u amerenst /local/repository/f3/experiments/micro-benchmark/run-nostats.sh /var/ceph/f$i $1 $i >> /local/repository/f3/experiments/disk-speed-tests/dd-test/e2e-ceph-after-ceph-$1
#    timeout 600 sudo -u amerenst kubectl exec testing1-pod-kubes1 -nopenwhisk -- rm /var/ceph/f$i
#done

rm lock
