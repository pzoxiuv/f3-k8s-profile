#!/bin/bash

### It's f3-fuse-driver that's doing the writing
### iostat doesn't seem to be updated immediatly?

### reader seems to cause an extra 4MB to be accounted for
### in read_bytes??? But iostat doesn't report any disk
### actually getting the io
### >>>> it always roughly matches rchar, so clearly it's
### not accounting correctly.  Need to use iostat as groundtruth
### for what is getting read from disk vs cache

#set -o xtrace

f3_csi_pod() {
	kubectl get pod -lapp=csi-f3-node --field-selector spec.nodeName=$1 -o=name
}

f3_csi_logs() {
	kubectl logs `f3_csi_pod "$1"` "${@:2}"
}

f3_csi_exec() {
	kubectl exec `f3_csi_pod "$1"` "${@:2}"
}

f3_stats() {
    f3_csi_exec $1 -c$2 -- cat /proc/$3/stat | awk '{print $14/100","$15/100","$42/100}'
}

stat_diff2() {
    for i in `seq 1 3`; do
        a=`echo $2 | cut -d, -f$i`
        b=`echo $1 | cut -d, -f$i`
        echo -n `echo "$a - $b" | bc`,
    done
    echo ""
}

# stat_diff $before $after $fieldnum
function stat_diff() {
    echo -n $(( `echo $2 | cut -d',' -f$3` - `echo $1 | cut -d',' -f$3` ))
}


function netstat_diff() {
    #echo "XXX"
    #echo $1
    #echo $2
    for i in `seq 1 5`; do
        a=`echo $2 | cut -d, -f$i`
        b=`echo $1 | cut -d, -f$i`
        #echo $a" "$b
        echo -n $(( $(( $a - $b )) / 1024 / 1024 )),
    done
    echo ""
    #echo "YYY"
}

#set -o xtrace

function netstat_app_r() {
    res=""
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        res=${res},`ssh $n "grep en.16 /proc/net/dev" | awk '{r += $2} END {print r}'`
    done
    res=`echo $res | cut -c2-`
    echo -n $res
}

function netstat_app_t() {
    res=""
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        res=${res},`ssh $n "grep en.16 /proc/net/dev" | awk '{t += $10} END {print t}'`
    done
    res=`echo $res | cut -c2-`
    echo -n $res
}

function netstat_sto_r() {
    res=""
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        res=${res},`ssh $n "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{r += $2} END {print r}'`
    done
    res=`echo $res | cut -c2-`
    echo -n $res
}

function netstat_sto_t() {
    res=""
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        res=${res},`ssh $n "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{t += $10} END {print t}'`
    done
    res=`echo $res | cut -c2-`
    echo -n $res
}

RCHAR=1
WCHAR=2
RBYTE=3
WBYTE=4

CEPH_NODE=kubes-stor

k1_lc=`lsblk | grep local-cache | awk '{print $1}'`
k3_lc=`ssh kubes3 lsblk | grep local-cache | awk '{print $1}'`

FILESIZE=$(( $2 * 1024 * 1024 ))

kubectl exec testing1-pod-kubes1 -nopenwhisk -- /vmtouch -q -e $1

iostat -m sde | grep sde
ssh $CEPH_NODE iostat -m sdd | grep sdf
#f3_csi_exec kubes1 -cf3 `f3_csi_exec kubes1 -cf3 -- pgrep f3-fuse-driver`
wbytes_k1_b=`awk '{printf "%d",$7*512/1024/1024}' /sys/block/$k1_lc/stat`
wbytes_ks_b=`ssh $CEPH_NODE "awk '{printf \"%d\",\\\$7*512/1024/1024}' /sys/block/sdf/stat"`
#f3_stats_b=$(f3_stats kubes1 f3 `f3_csi_exec kubes1 -cf3 -- pgrep f3-fuse-driver`)
net_app_r_b=`netstat_app_r`
net_app_t_b=`netstat_app_t`
net_sto_r_b=`netstat_sto_r`
net_sto_t_b=`netstat_sto_t`
#net_app_r_b=`ansible all -mshell -a "grep en.16 /proc/net/dev" | awk '{r += $2} END {print r}'`
#net_app_t_b=`ansible all -mshell -a "grep en.16 /proc/net/dev" | awk '{t += $10} END {print t}'`
#net_sto_r_b=`ansible all -mshell -a "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{r += $2} END {print r}'`
#net_sto_t_b=`ansible all -mshell -a "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{t += $10} END {print t}'`
before1=$(date +%s)
#kubectl exec testing1-pod-kubes1 -nopenwhisk -- bash -c "/writer $1 $FILESIZE; cat /proc/\$\$/io"
kubectl exec testing1-pod-kubes1 -nopenwhisk -- bash -c "/writer $1 $FILESIZE"
after1=$(date +%s)
#f3_stats_a=$(f3_stats kubes1 f3 `f3_csi_exec kubes1 -cf3 -- pgrep f3-fuse-driver`)
wbytes_k1_a=`awk '{printf "%d",$7*512/1024/1024}' /sys/block/$k1_lc/stat`
wbytes_ks_a=`ssh $CEPH_NODE "awk '{printf \"%d\",\\\$7*512/1024/1024}' /sys/block/sdf/stat"`
#echo "WRITE $(( $after1 - $before1 )) s"
#echo "k1_f3,"`stat_diff2 $f3_stats_b $f3_stats_a`
#f3_csi_exec kubes1 -cf3 `f3_csi_exec kubes1 -cf3 -- pgrep f3-fuse-driver`
#net_app_r_a=`ansible all -mshell -a "grep en.16 /proc/net/dev" | awk '{r += $2} END {print r}'`
#net_app_t_a=`ansible all -mshell -a "grep en.16 /proc/net/dev" | awk '{t += $10} END {print t}'`
#net_sto_r_a=`ansible all -mshell -a "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{r += $2} END {print r}'`
#net_sto_t_a=`ansible all -mshell -a "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{t += $10} END {print t}'`
#write_app_r=$(( $net_app_r_a - $net_app_r_b ))
#write_app_t=$(( $net_app_t_a - $net_app_t_b ))
#write_sto_r=$(( $net_sto_r_a - $net_sto_r_b ))
#write_sto_t=$(( $net_sto_t_a - $net_sto_t_b ))
net_app_r_a=`netstat_app_r`
net_app_t_a=`netstat_app_t`
net_sto_r_a=`netstat_sto_r`
net_sto_t_a=`netstat_sto_t`
write_app_r=`netstat_diff $net_app_r_b $net_app_r_a`
write_app_t=`netstat_diff $net_app_t_b $net_app_t_a`
write_sto_r=`netstat_diff $net_sto_r_b $net_sto_r_a`
write_sto_t=`netstat_diff $net_sto_t_b $net_sto_t_a`

iostat -m sde | grep sde
ssh kubes3 iostat -m sdd | grep sdd
ssh $CEPH_NODE iostat -m sdd | grep sdf

net_app_r_b=`netstat_app_r`
net_app_t_b=`netstat_app_t`
net_sto_r_b=`netstat_sto_r`
net_sto_t_b=`netstat_sto_t`
#net_app_r_b=`ansible all -mshell -a "grep en.16 /proc/net/dev" | awk '{r += $2} END {print r}'`
#net_app_t_b=`ansible all -mshell -a "grep en.16 /proc/net/dev" | awk '{t += $10} END {print t}'`
#net_sto_r_b=`ansible all -mshell -a "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{r += $2} END {print r}'`
#net_sto_t_b=`ansible all -mshell -a "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{t += $10} END {print t}'`
rbytes_k1_b=`awk '{printf "%d",$3*512/1024/1024}' /sys/block/$k1_lc/stat`
rbytes_k3_b=`ssh kubes3 "awk '{printf \"%d\",\\\$3*512/1024/1024}' /sys/block/$k3_lc/stat"`
wbytes_k3_b=`ssh kubes3 "awk '{printf \"%d\",\\\$7*512/1024/1024}' /sys/block/$k3_lc/stat"`
rbytes_ks_b=`ssh $CEPH_NODE "awk '{printf \"%d\",\\\$3*512/1024/1024}' /sys/block/sdf/stat"`
#server_k1_before=`sudo /usr/local/bin/f3-io-stats /app/server`
#client_k3_before=`ssh kubes3 sudo /usr/local/bin/f3-io-stats /app/client`
#f3_k1_before=`sudo /usr/local/bin/f3-io-stats f3-fuse-driver`
#f3_k3_before=`ssh kubes3 sudo /usr/local/bin/f3-io-stats f3-fuse-driver`

#server_stats_b=$(f3_stats kubes1 server-uds 1)
#client_stats_b=$(f3_stats kubes3 client-uds 1)
#f3_k1_b=$(f3_stats kubes1 f3 `f3_csi_exec kubes1 -cf3 -- pgrep f3-fuse-driver`)
#f3_k3_b=$(f3_stats kubes3 f3 `f3_csi_exec kubes3 -cf3 -- pgrep f3-fuse-driver`)
before2=$(date +%s)
#kubectl exec testing1-pod-kubes3 -nopenwhisk -- bash -c "/reader $1; cat /proc/\$\$/io"
kubectl exec testing1-pod-kubes3 -nopenwhisk -- bash -c "/reader $1"
after2=$(date +%s)
#server_stats_a=$(f3_stats kubes1 server-uds 1)
#client_stats_a=$(f3_stats kubes3 client-uds 1)
#f3_k1_a=$(f3_stats kubes1 f3 `f3_csi_exec kubes1 -cf3 -- pgrep f3-fuse-driver`)
#f3_k3_a=$(f3_stats kubes3 f3 `f3_csi_exec kubes3 -cf3 -- pgrep f3-fuse-driver`)

#echo "server,"`stat_diff2 $server_stats_b $server_stats_a`
#echo "client,"`stat_diff2 $client_stats_b $client_stats_a`
#echo "k1_f3,"`stat_diff2 $f3_k1_b $f3_k1_a`
#echo "k3_f3,"`stat_diff2 $f3_k3_b $f3_k3_a`

rbytes_k1_a=`awk '{printf "%d",$3*512/1024/1024}' /sys/block/$k1_lc/stat`
rbytes_k3_a=`ssh kubes3 "awk '{printf \"%d\",\\\$3*512/1024/1024}' /sys/block/$k3_lc/stat"`
wbytes_k3_a=`ssh kubes3 "awk '{printf \"%d\",\\\$7*512/1024/1024}' /sys/block/$k3_lc/stat"`
rbytes_ks_a=`ssh $CEPH_NODE "awk '{printf \"%d\",\\\$3*512/1024/1024}' /sys/block/sdf/stat"`
#server_k1_after=`sudo /usr/local/bin/f3-io-stats /app/server`
#client_k3_after=`ssh kubes3 sudo /usr/local/bin/f3-io-stats /app/client`
#f3_k1_after=`sudo /usr/local/bin/f3-io-stats f3-fuse-driver`
#f3_k3_after=`ssh kubes3 sudo /usr/local/bin/f3-io-stats f3-fuse-driver`
#net_app_r_a=`ansible all -mshell -a "grep en.16 /proc/net/dev" | awk '{r += $2} END {print r}'`
#net_app_t_a=`ansible all -mshell -a "grep en.16 /proc/net/dev" | awk '{t += $10} END {print t}'`
#net_sto_r_a=`ansible all -mshell -a "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{r += $2} END {print r}'`
#net_sto_t_a=`ansible all -mshell -a "grep 'en.[3|1][3|9]' /proc/net/dev" | awk '{t += $10} END {print t}'`
#read_app_r=$(( $net_app_r_a - $net_app_r_b ))
#read_app_t=$(( $net_app_t_a - $net_app_t_b ))
#read_sto_r=$(( $net_sto_r_a - $net_sto_r_b ))
#read_sto_t=$(( $net_sto_t_a - $net_sto_t_b ))
net_app_r_a=`netstat_app_r`
net_app_t_a=`netstat_app_t`
net_sto_r_a=`netstat_sto_r`
net_sto_t_a=`netstat_sto_t`
read_app_r=`netstat_diff $net_app_r_b $net_app_r_a`
read_app_t=`netstat_diff $net_app_t_b $net_app_t_a`
read_sto_r=`netstat_diff $net_sto_r_b $net_sto_r_a`
read_sto_t=`netstat_diff $net_sto_t_b $net_sto_t_a`

iostat -m sde | grep sde
ssh kubes3 iostat -m sdd | grep sdd
ssh $CEPH_NODE iostat -m sdd | grep sdf

#echo "READ $(( $after2 - $before2 )) s"

echo "$(( $after2 - $before1 )) s total $1 YYY"

k1_reads=$(( $rbytes_k1_a - $rbytes_k1_b ))
k1_writes=$(( $wbytes_k1_a - $wbytes_k1_b ))
k3_reads=$(( $rbytes_k3_a - $rbytes_k3_b ))
k3_writes=$(( $wbytes_k3_a - $wbytes_k3_b ))
ks_reads=$(( $rbytes_ks_a - $rbytes_ks_b ))
ks_writes=$(( $wbytes_ks_a - $wbytes_ks_b ))

#echo $k1_reads,$k1_writes,$k3_reads,$k3_writes

#echo $f3_k1_before
#echo $f3_k1_after
#echo $f3_k3_before
#echo $f3_k3_after

#echo A $server_k1_before
#echo B $server_k1_after
#echo C $f3_k1_before
#echo D $f3_k1_after
#echo E $f3_k3_before
#echo F $f3_k3_after

echo "k1 reads: $k1_reads"
echo "k1 writes: $k1_writes"
echo "k3 reads: $k3_reads"
echo "k3 writes: $k3_writes"
echo "ks reads: $ks_reads"
echo "ks writes: $ks_writes"
#echo "write app recv: $(( $write_app_r / 1024 / 1024 ))"
#echo "write app transmit: $(( $write_app_t / 1024 / 1024 ))"
#echo "write sto recv: $(( $write_sto_r / 1024 / 1024 ))"
#echo "write sto transmit: $(( $write_sto_t / 1024 / 1024 ))"
echo "write app recv: $write_app_r"
echo "write app tran: $write_app_t"
echo "write sto recv: $write_sto_r"
echo "write sto tran: $write_sto_t"
#echo "read app recv: $(( $read_app_r / 1024 / 1024 ))"
#echo "read app transmit: $(( $read_app_t / 1024 / 1024 ))"
#echo "read sto recv: $(( $read_sto_r / 1024 / 1024 ))"
#echo "read sto transmit: $(( $read_sto_t / 1024 / 1024 ))"
echo "read app recv: $read_app_r"
echo "read app tran: $read_app_t"
echo "read sto recv: $read_sto_r"
echo "read sto tran: $read_sto_t"

#echo "server k1 rchar: " `stat_diff $server_k1_before $server_k1_after $RCHAR`
#echo "server k1 wchar: " `stat_diff $server_k1_before $server_k1_after $WCHAR`
#echo "server k1 rbyte: " `stat_diff $server_k1_before $server_k1_after $RBYTE`
#echo "server k1 wbyte: " `stat_diff $server_k1_before $server_k1_after $WBYTE`
#
#echo "client k3 rchar: " `stat_diff $client_k3_before $client_k3_after $RCHAR`
#echo "client k3 wchar: " `stat_diff $client_k3_before $client_k3_after $WCHAR`
#echo "client k3 rbyte: " `stat_diff $client_k3_before $client_k3_after $RBYTE`
#echo "client k3 wbyte: " `stat_diff $client_k3_before $client_k3_after $WBYTE`
#
#echo "f3 k1 rchar: " `stat_diff $f3_k1_before $f3_k1_after $RCHAR`
#echo "f3 k1 wchar: " `stat_diff $f3_k1_before $f3_k1_after $WCHAR`
#echo "f3 k1 rbyte: " `stat_diff $f3_k1_before $f3_k1_after $RBYTE`
#echo "f3 k1 wbyte: " `stat_diff $f3_k1_before $f3_k1_after $WBYTE`
#
#echo "f3 k3 rchar: " `stat_diff $f3_k3_before $f3_k3_after $RCHAR`
#echo "f3 k3 wchar: " `stat_diff $f3_k3_before $f3_k3_after $WCHAR`
#echo "f3 k3 rbyte: " `stat_diff $f3_k3_before $f3_k3_after $RBYTE`
#echo "f3 k3 wbyte: " `stat_diff $f3_k3_before $f3_k3_after $WBYTE`

#for i in `seq 1 4`; do
#    echo -n `stat_diff $server_k1_before $server_k1_after $i`,
#done
#echo ""
#
#for i in `seq 1 4`; do
#    echo -n `stat_diff $client_k3_before $client_k3_after $i`,
#done
#echo ""
#
#for i in `seq 1 4`; do
#    echo -n `stat_diff $f3_k1_before $f3_k1_after $i`,
#done
#echo ""
#
#for i in `seq 1 4`; do
#    echo -n `stat_diff $f3_k3_before $f3_k3_after $i`,
#done
#echo ""
