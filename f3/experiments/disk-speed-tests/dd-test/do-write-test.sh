#!/bin/bash

#umount /mnt/local-cache
echo 1 > /proc/sys/vm/drop_caches
#mount /dev/sda4 /mnt/local-cache
/usr/bin/time -f "TOTAL,$1,%e,`date +%s`" bash -c "dd if=/dev/zero of=/mnt/local-cache/f bs=4M count=$2; sync"
