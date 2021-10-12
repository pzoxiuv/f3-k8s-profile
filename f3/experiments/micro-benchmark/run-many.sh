#!/bin/bash

NET_APP_R='ssh $n "grep en.16 /proc/net/dev" | awk '"'"'{r += $2} END {print r}'"'"''
NET_APP_T='ssh $n "grep en.16 /proc/net/dev" | awk '"'"'{r += $10} END {print r}'"'"''
NET_STO_R='ssh $n "grep '"'"'en.[3|1][3|9]'"'"' /proc/net/dev" | awk '"'"'{r += $2} END {print r}'"'"''
NET_STO_T='ssh $n "grep '"'"'en.[3|1][3|9]'"'"' /proc/net/dev" | awk '"'"'{r += $10} END {print r}'"'"''

MEM_AVAIL_MAX='ssh $n "get-mem-stats.sh $2 $3" | grep -v VAL | awk '"'"'{print $1}'"'"''
MEM_AVAIL_AVG='ssh $n "get-mem-stats.sh $2 $3" | grep -v VAL | awk '"'"'{print $2}'"'"''

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

function netstat_diff() {
    for i in `seq 1 5`; do
        a=`echo $2 | cut -d, -f$i`
        b=`echo $1 | cut -d, -f$i`
        echo -n $(( $(( $a - $b )) / 1024 / 1024 )),
    done
    echo ""
}

function get_stats() {
    res=""
    #for n in kubes1; do
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        res=${res},`eval $1`
    done
    res=`echo $res | cut -c2-`
    echo -n $res
    echo ""
}

function get_mem_stats() {
    #for n in kubes1; do
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        ssh $n "get-mem-stats.sh $1 $2" | grep VAL
    done | awk 'BEGIN {m=0; l=0} {s += $2; l += 1; if($2>m){m=$2;}} END {printf "%d,%d",m,s/l}'
    echo ""
}

function get_cpu_stats() {
    #for n in kubes1; do
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        ssh $n "get-mem-stats.sh $1 $2" | grep VAL
    done | awk 'BEGIN {m=0; l=0} {s += $3; l += 1; if($3>m){m=$3;}} END {printf "%d,%d",m,s/l}'
    echo ""
}

function start_iftop() {
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        ssh $n "start-iftop.sh" &
    done
}

function kill_iftop() {
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        ssh $n cp /tmp/ifout /tmp/ifout.prev
        ssh $n sudo pkill iftop
    done
}

function stats_iftop() {
    for n in kubes1 kubes2 kubes3 kubes-stor kubes-worker; do
        #ssh $n stop-iftop.sh $1
        ssh $n parse-iftop.py $1
    done
}

FILESIZE=$(( $2 * 1024 * 1024 ))
#FILESIZE=$(( $2 * 1024 ))

SC=`echo $1 | cut -d/ -f3`

kubectl exec testing1-pod-kubes1 -nopenwhisk -- /vmtouch -q -e $1

#net_app_r_b=`get_stats "$NET_APP_R"`
#net_app_t_b=`get_stats "$NET_APP_T"`
net_sto_r_b=`get_stats "$NET_STO_R"`
net_sto_t_b=`get_stats "$NET_STO_T"`

start_iftop

before1=$(date +%s)
#kubectl exec testing1-pod-kubes1 -nopenwhisk -- /writer $1 $FILESIZE
kubectl exec testing1-pod-kubes1 -nopenwhisk -- bash -c "/writer-many $1 $FILESIZE $3; cat /proc/\$\$/io"
after1=$(date +%s)
write_time=$(( $after1 - $before1 ))
echo "$(( $after1 - $before1 )) s total"

### PPP
sleep 20

#net_app_r_a=`get_stats "$NET_APP_R"`
#net_app_t_a=`get_stats "$NET_APP_T"`
net_sto_r_a=`get_stats "$NET_STO_R"`
net_sto_t_a=`get_stats "$NET_STO_T"`

kill_iftop
stats_iftop stat,$SC,net,write

echo $before1 $after1

echo "stat,$SC,mem_avg,write,nodes,`get_stats "$MEM_AVAIL_AVG" $before1 $after1`"
echo "stat,$SC,mem_max,write,nodes,`get_stats "$MEM_AVAIL_MAX" $before1 $after1`"
echo "stat,$SC,mem_max_avg,write,cluster,`get_mem_stats $before1 $after1`"
echo "stat,$SC,cpu_max_avg,write,cluster,`get_cpu_stats $before1 $after1`"

#echo "$SC,write_app_r,`netstat_diff $net_app_r_b $net_app_r_a`"
#echo "$SC,write_app_t,`netstat_diff $net_app_t_b $net_app_t_a`"
echo "stat,$SC,net,write,storage_network,recv,`netstat_diff $net_sto_r_b $net_sto_r_a`"
echo "stat,$SC,net,write,storage_network,transmit,`netstat_diff $net_sto_t_b $net_sto_t_a`"

#net_app_r_b=$net_app_r_a
#net_app_t_b=$net_app_t_a
net_sto_r_b=$net_sto_r_a
net_sto_t_b=$net_sto_t_a

echo AAA
kubectl exec testing1-pod-kubes3 -nopenwhisk -- ls -lh /var/f3 >/dev/null
kubectl exec testing1-pod-kubes3 -nopenwhisk -- stat $1 >/dev/null
kubectl exec testing1-pod-kubes3 -nopenwhisk -- stat $1 >/dev/null
kubectl exec testing1-pod-kubes3 -nopenwhisk -- ls -lh /var/f3 >/dev/null
echo BBB

#server_stats_b=$(f3_stats kubes1 server-uds 1)
#client_stats_b=$(f3_stats kubes3 client-uds 1)
#f3_k1_b=$(f3_stats kubes1 f3 `f3_csi_exec kubes1 -cf3 -- pgrep f3-fuse-driver`)
#f3_k3_b=$(f3_stats kubes3 f3 `f3_csi_exec kubes3 -cf3 -- pgrep f3-fuse-driver`)

start_iftop

before2=$(date +%s)
#kubectl exec testing1-pod-kubes3 -nopenwhisk -- /reader $1
kubectl exec testing1-pod-kubes3 -nopenwhisk -- bash -c "/reader-many $1 $3; cat /proc/\$\$/io"
after2=$(date +%s)
read_time=$(( $after2 - $before2 ))
echo $before2 $after2
echo "$(( $after2 - $before2 )) s total"
echo "$(( $write_time + $read_time )) s total $1 YYY"

sleep 20

#server_stats_a=$(f3_stats kubes1 server-uds 1)
#client_stats_a=$(f3_stats kubes3 client-uds 1)
#f3_k1_a=$(f3_stats kubes1 f3 `f3_csi_exec kubes1 -cf3 -- pgrep f3-fuse-driver`)
#f3_k3_a=$(f3_stats kubes3 f3 `f3_csi_exec kubes3 -cf3 -- pgrep f3-fuse-driver`)

#net_app_r_a=`get_stats "$NET_APP_R"`
#net_app_t_a=`get_stats "$NET_APP_T"`
net_sto_r_a=`get_stats "$NET_STO_R"`
net_sto_t_a=`get_stats "$NET_STO_T"`

kill_iftop
stats_iftop stat,$SC,net,read

echo "stat,$SC,mem_avg,read,nodes,`get_stats "$MEM_AVAIL_AVG" $before2 $after2`"
echo "stat,$SC,mem_max,read,nodes,`get_stats "$MEM_AVAIL_MAX" $before2 $after2`"
echo "stat,$SC,mem_max_avg,read,cluster,`get_mem_stats $before2 $after2`"
echo "stat,$SC,cpu_max_avg,read,cluster,`get_cpu_stats $before2 $after2`"

#echo "$SC,read_app_r,`netstat_diff $net_app_r_b $net_app_r_a`"
#echo "$SC,read_app_t,`netstat_diff $net_app_t_b $net_app_t_a`"
echo "stat,$SC,net,read,storage_network,recv,`netstat_diff $net_sto_r_b $net_sto_r_a`"
echo "stat,$SC,net,read,storage_network,transmit,`netstat_diff $net_sto_t_b $net_sto_t_a`"
