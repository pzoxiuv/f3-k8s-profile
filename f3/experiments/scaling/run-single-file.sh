#!/bin/bash

#set -o xtrace

if [ -f lock ]; then
    echo "Already running?"
    exit
fi

touch lock

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

MYDIR=`dirname $0`

# 1 = sc
# 2 = outdir
# 3 = count
# 4 = # clients
# 5 = # readers per client
# 6 = target dir

sc=$1

mb=10000
FILESIZE=$(( $mb * 1024 * 1024 ))

OUTDIR_BASE=$MYDIR/single-file-$2-$4-$5-$mb
target_dir=$6

mkdir -p $OUTDIR_BASE
if [ `find $OUTDIR_BASE -mindepth 1 -type d | wc -l` -gt 0 ]; then
	lastdir=`find $OUTDIR_BASE -mindepth 1 -type d -printf '%f\n' | sort -n | tail -n1`
else
	lastdir=0
fi
startdir=$(( $lastdir + 1 ))
enddir=$(( $startdir + $3 - 1 ))

readers=$4

echo "master bin: $master_bin"
echo "outdir base: $OUTDIR_BASE"
echo "untardir: $untar_dir"

RUNTIME=120

for i in `seq $startdir $enddir`; do

    if [ -f stop ]; then
        exit
    fi

    echo "TOP OF LOOP $i ${sc} $1 $2 $3 $4 $5 $6 $#"

    OUTDIR=$OUTDIR_BASE/$i
    echo "outdir: $OUTDIR"
    mkdir -p $OUTDIR

    ###### Setup:

    ansible all --become -a "/usr/sbin/rmmod fuse_stats"
    ansible all --become -a "/usr/sbin/insmod /usr/local/bin/fuse-stats.ko"

    kubectl apply -f /local/repository/f3/experiments/scaling/writer.yaml
    for j in `seq 3 $(( $readers + 2 ))`; do
        kubectl apply -f /local/repository/f3/experiments/scaling/reader-deployment-$j.yaml
        kubectl scale deployment reader-$j --replicas=$5 -nopenwhisk
    done
    kubectl apply -f /local/repository/f3/experiments/scaling/f3-pvc.yaml
    #kubectl apply -f /local/repository/f3/experiments/scaling/minio-pvc.yaml
    kubectl apply -f /local/repository/f3/experiments/scaling/ceph-pvc-replicated.yaml
    kubectl wait --for=condition=ready pod writer -nopenwhisk --timeout=200s
    for j in `seq 3 $(( $readers + 2 ))`; do
        #kubectl wait --for=condition=ready pod reader-$j -nopenwhisk --timeout=200s
        kubectl rollout status deployment/reader-$j --timeout=300s -nopenwhisk
    done

    kubectl exec -n openwhisk writer -- mkdir /var/$sc/$target_dir

    ansible all --become -mshell -a "echo 1 >/proc/fuse-stats"

    ###### Run:

    start=$(date +%s)
    echo -n "$(date +%s)," > $OUTDIR/start_stop
    echo -n "$(date +%s)," > $OUTDIR/writer_start_stop
    kubectl exec writer -nopenwhisk -- /writer /var/$sc/$target_dir/f $FILESIZE | tee $OUTDIR/writer.out
    echo "$(date +%s)," >> $OUTDIR/writer_start_stop
    echo -n "$(date +%s)," > $OUTDIR/reader_start_stop
    #for j in `seq 3 $(( $readers + 2 ))`; do
    #    kubectl exec reader-$j -nopenwhisk -- /reader /var/$sc/$target_dir/f $FILESIZE | tee $OUTDIR/reader.$j.out &
    #done
    for p in `kubectl get pods -lrole=reader -nopenwhisk -o name`; do
        kubectl exec $p -nopenwhisk -- /reader /var/$sc/$target_dir/f $FILESIZE | tee $OUTDIR/`echo $p | sed 's/\//-/g'`.out &
    done
    wait
    echo "$(date +%s)," >> $OUTDIR/reader_start_stop

    now=$(date +%s)
    elapsed=$(( $now - $start ))
    sleeptime=$(( $RUNTIME - $elapsed ))
    echo $start $now $sleeptime $RUNTIME $elapsed
    sleep $sleeptime

    echo "$(date +%s)," >> $OUTDIR/start_stop

    ###### Collect end of run stats:

    # Twice for good luck (...there's a bug, first read sometimes doesn't return anything)
    ansible all -a "cat /proc/fuse-stats" >$OUTDIR/fuse_ops_by_node
    ansible all -a "cat /proc/fuse-stats" >$OUTDIR/fuse_ops_by_node
    ./agg_ops.py $OUTDIR/fuse_ops_by_node >$OUTDIR/fuse_ops

    ansible all -m fetch -a "src=/var/log/dstat/stats dest=$OUTDIR/{{ inventory_hostname }}-dstat.stats flat=true" --become

    kubectl logs -luser-action-pod=true -nopenwhisk --tail -1 >$OUTDIR/logs

    ansible all -m shell -a "/usr/sbin/lsmod | grep ceph" >$OUTDIR/mods
    cp $0 $OUTDIR/runner

    ###### Cleanup:

    ansible all --become -m shell -a "rm -rf /mnt/local-cache/tempdir/*"
    kubectl delete -f /local/repository/f3/experiments/scaling/writer.yaml &
    for j in `seq 3 $(( $readers + 2 ))`; do
        kubectl delete -f /local/repository/f3/experiments/scaling/reader-deployment-$j.yaml &
    done
    kubectl delete -f /local/repository/f3/experiments/scaling/reader-3.yaml &
    kubectl delete -f /local/repository/f3/experiments/scaling/reader-4.yaml &
    kubectl delete -f /local/repository/f3/experiments/scaling/f3-pvc.yaml &
    #kubectl delete -f /local/repository/f3/experiments/scaling/minio-pvc.yaml
    kubectl delete -f /local/repository/f3/experiments/scaling/ceph-pvc-replicated.yaml &
    until cleanup-pod.sh writer -nopenwhisk; do
        echo "Waiting for containers to exit..."
        sleep 60
    done
    for j in `seq 3 $(( $readers + 2 ))`; do
	    until cleanup-pod.sh -lapp=reader-$j -nopenwhisk; do
		echo "Waiting for containers to exit..."
		sleep 60
	    done
    done
    wait

    if [ $sc = "f3" ]; then
	    kubectl rollout restart ds csi-f3-node
	    kubectl rollout status ds csi-f3-node --timeout=1200s
    fi

    python3 ./trim-dstat.py $OUTDIR

    echo "done loop"

done

rm lock
