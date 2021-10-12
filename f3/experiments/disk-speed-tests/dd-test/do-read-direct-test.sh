#!/bin/bash

umount /mnt/local-cache
echo 1 > /proc/sys/vm/drop_caches
mount /dev/sda4 /mnt/local-cache
/usr/bin/time -f "TOTAL,$1,%e,`date +%s`" bash -c "dd if=/mnt/local-cache/f of=/dev/null bs=4M count=$2 iflag=direct; sync"
