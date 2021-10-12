#!/bin/bash

if [ -f lock ]; then
    echo "Already running?"
    exit
fi

touch lock

COUNT=$(( $1 / 4 ))

ITER=2

for i in `seq 0 $ITER`; do 

    sudo -u alex kubectl apply -f /home/alex/f3/experiments/f3-only-pvc.yaml
    sudo -u alex kubectl apply -f /home/alex/f3/experiments/f3-pod-kubes1.yaml
    sudo -u alex kubectl apply -f /home/alex/f3/experiments/f3-pod-kubes3.yaml
    sudo -u alex kubectl wait --for=condition=ready pod f3-testing1-pod-kubes1 -nopenwhisk --timeout=200s
    sudo -u alex kubectl wait --for=condition=ready pod f3-testing1-pod-kubes3 -nopenwhisk --timeout=200s
    sudo -u alex bash -c "cd /home/alex/f3/experiments/micro-benchmark/; ./copy-files-f3.sh"

    timeout 600 sudo -u alex /home/alex/f3/experiments/micro-benchmark/run-nostats-f3only.sh /var/f3/f$i.id $1 $i >> /home/alex/f3/experiments/disk-speed-tests/dd-test/e2e-f3-before-1500-limit-1500-res-$1

    sudo -u alex kubectl delete -f /home/alex/f3/experiments/f3-pod-kubes1.yaml
    sudo -u alex kubectl delete -f /home/alex/f3/experiments/f3-pod-kubes3.yaml
    sudo -u alex kubectl delete -f /home/alex/f3/experiments/f3-only-pvc.yaml
    sudo -u alex kubectl rollout restart ds csi-f3-node
    sudo -u alex kubectl rollout status ds/csi-f3-node --timeout=300s
done

for i in `seq 0 $ITER`; do
    {
    date
    echo "AAA" `date +%s`

    umount /mnt/testdisk
    echo 1 > /proc/sys/vm/drop_caches
    mount /dev/sdf /mnt/testdisk

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/dev/zero of=/mnt/testdisk/f bs=4M count=$COUNT; sync"

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/write-f3-1500-limit-1500-res-$1 2>&1

    {
    date
    echo "AAA" `date +%s`

    umount /mnt/testdisk
    echo 1 > /proc/sys/vm/drop_caches
    mount /dev/sdf /mnt/testdisk

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/dev/zero of=/mnt/testdisk/f bs=4M count=$COUNT oflag=direct; sync"

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/write-direct-f3-1500-limit-1500-res-$1 2>&1

    {
    date
    echo "AAA" `date +%s`

    umount /mnt/testdisk
    echo 1 > /proc/sys/vm/drop_caches
    mount /dev/sdf /mnt/testdisk

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/mnt/testdisk/f of=/dev/null bs=4M count=$COUNT iflag=direct"

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/read-direct-f3-1500-limit-1500-res-$1 2>&1

    {
    date
    echo "AAA" `date +%s`

    umount /mnt/testdisk
    echo 1 > /proc/sys/vm/drop_caches
    mount /dev/sdf /mnt/testdisk

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/mnt/testdisk/f of=/dev/null bs=4M count=$COUNT"

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/read-f3-1500-limit-1500-res-$1 2>&1

    {
    date
    echo "AAA" `date +%s`

    sudo -u alex ssh kubes3 iperf -c 130.245.126.249 -n $1M

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/iperf-k3-k1-1500-limit-1500-res-$1 2>&1

    {
    date
    echo "AAA" `date +%s`

    iperf -c 10.245.126.125 -n $1M

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/iperf-k1-freenas-1500-limit-1500-res-$1 2>&1

done

#for i in `seq 0 $ITER`; do 
#    timeout 600 sudo -u alex /home/alex/f3/experiments/micro-benchmark/run-nostats.sh /var/ceph/f$i $1 $i >> /home/alex/f3/experiments/disk-speed-tests/dd-test/e2e-ceph-after-ceph-$1
#    timeout 600 sudo -u alex kubectl exec testing1-pod-kubes1 -nopenwhisk -- rm /var/ceph/f$i
#done

rm lock
