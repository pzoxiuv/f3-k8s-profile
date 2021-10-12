#!/bin/bash

if [ -f lock ]; then
    echo "Already running?"
    exit
fi

touch lock

COUNT=$(( $1 / 4 ))

ITER=2

for i in `seq 0 $ITER`; do 
    timeout 600 sudo -u alex /home/alex/f3/experiments/micro-benchmark/run-nostats.sh /var/ceph/f$i $1 $i >> /home/alex/f3/experiments/disk-speed-tests/dd-test/e2e-ceph-before-$1-2
    timeout 600 sudo -u alex kubectl exec testing1-pod-kubes1 -nopenwhisk -- rm /var/ceph/f$i
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
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/write-$1-2 2>&1

    {
    date
    echo "AAA" `date +%s`

    umount /mnt/testdisk
    echo 1 > /proc/sys/vm/drop_caches
    mount /dev/sdf /mnt/testdisk

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/dev/zero of=/mnt/testdisk/f bs=4M count=$COUNT oflag=direct; sync"

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/write-direct-$1-2 2>&1

    {
    date
    echo "AAA" `date +%s`

    umount /mnt/testdisk
    echo 1 > /proc/sys/vm/drop_caches
    mount /dev/sdf /mnt/testdisk

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/mnt/testdisk/f of=/dev/null bs=4M count=$COUNT iflag=direct"

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/read-direct-$1-2 2>&1

    {
    date
    echo "AAA" `date +%s`

    umount /mnt/testdisk
    echo 1 > /proc/sys/vm/drop_caches
    mount /dev/sdf /mnt/testdisk

    /usr/bin/time -f "TOTAL2,$i,%e,`date +%s`" bash -c "dd if=/mnt/testdisk/f of=/dev/null bs=4M count=$COUNT"

    echo "---"
    } >> /home/alex/f3/experiments/disk-speed-tests/dd-test/read-$1-2 2>&1

done

#sleep 60

for i in `seq 0 $ITER`; do 
    timeout 600 sudo -u alex /home/alex/f3/experiments/micro-benchmark/run-nostats.sh /var/ceph/f$i $1 $i >> /home/alex/f3/experiments/disk-speed-tests/dd-test/e2e-ceph-after-$1-2
    timeout 600 sudo -u alex kubectl exec testing1-pod-kubes1 -nopenwhisk -- rm /var/ceph/f$i
done

rm lock
