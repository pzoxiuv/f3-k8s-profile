#!/bin/bash

if [ -f lock ]; then
    echo "Already running?"
    exit
fi

touch lock

COUNT=$(( $1 / 4 ))

ITER=2

for i in `seq 0 $ITER`; do 
    timeout 600 sudo -u alex /home/alex/f3/experiments/micro-benchmark/run-nostats.sh /var/ceph/f$i $1 $i >> /home/alex/f3/experiments/disk-speed-tests/dd-test/e2e-ceph-before-ceph-$1
    timeout 600 sudo -u alex kubectl exec testing1-pod-kubes1 -nopenwhisk -- rm /var/ceph/f$i
done

for i in `seq 0 $ITER`; do
    {
    date
    echo "AAA" `date +%s`

    sudo -u alex kubectl delete -f /home/alex/f3/experiments/ceph-pod-kubes1.yaml
    sudo -u alex kubectl delete -f /home/alex/f3/experiments/ceph-pod-kubes3.yaml
    sudo -u alex kubectl delete -f /home/alex/f3/experiments/ceph-ceph-nonf3-pvc.yaml
    sudo -u alex kubectl apply -f /home/alex/f3/experiments/ceph-ceph-nonf3-pvc.yaml
    sudo -u alex kubectl apply -f /home/alex/f3/experiments/ceph-pod-kubes1.yaml
    sudo -u alex kubectl apply -f /home/alex/f3/experiments/ceph-pod-kubes3.yaml
    sudo -u alex kubectl wait --for=condition=ready pod ceph-testing1-pod-kubes1 -nopenwhisk --timeout=200s
    sudo -u alex kubectl wait --for=condition=ready pod ceph-testing1-pod-kubes3 -nopenwhisk --timeout=200s

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "sudo -u alex kubectl exec -ti -nopenwhisk ceph-testing1-pod-kubes1 -- bash -c \"dd if=/dev/zero of=/var/ceph/f bs=4M count=$COUNT; sync\""

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/write-ceph-$1 2>&1

    {
    date
    echo "AAA" `date +%s`

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "sudo -u alex kubectl exec -ti -nopenwhisk ceph-testing1-pod-kubes3 -- bash -c \"dd if=/var/ceph/f of=/dev/null bs=4M count=$COUNT; sync\""

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/read-ceph-$1 2>&1

#    {
#    date
#    echo "AAA" `date +%s`
#
#    umount /mnt/testdisk
#    echo 1 > /proc/sys/vm/drop_caches
#    mount /dev/sdf /mnt/testdisk
#
#    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/mnt/testdisk/f of=/dev/null bs=4M count=$COUNT iflag=direct"
#
#    echo "---"
#    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/read-direct-$1-2 2>&1
#
#    {
#    date
#    echo "AAA" `date +%s`
#
#    umount /mnt/testdisk
#    echo 1 > /proc/sys/vm/drop_caches
#    mount /dev/sdf /mnt/testdisk
#
#    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/mnt/testdisk/f of=/dev/null bs=4M count=$COUNT"
#
#    echo "---"
#    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/read-$1-2 2>&1

done

#sleep 60

for i in `seq 0 $ITER`; do 
    timeout 600 sudo -u alex /home/alex/f3/experiments/micro-benchmark/run-nostats.sh /var/ceph/f$i $1 $i >> /home/alex/f3/experiments/disk-speed-tests/dd-test/e2e-ceph-after-ceph-$1
    timeout 600 sudo -u alex kubectl exec testing1-pod-kubes1 -nopenwhisk -- rm /var/ceph/f$i
done

rm lock
