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
# 4 = # workers
# 5 = middle name
# 6 = id?

sc=$1
numworkers=$4

OUTDIR_BASE=$MYDIR/$2-$5-$4
master_bin=master_v7
if [ $# -gt 5 ]; then
    master_bin=master_v7_id
#else
#    if [ $sc = "f3" ]; then
#        OUTDIR_BASE=$MYDIR/$2-${sc}non-$4
#    fi
fi


mkdir -p $OUTDIR_BASE
if [ `find $OUTDIR_BASE -mindepth 1 -type d | wc -l` -gt 0 ]; then
	lastdir=`find $OUTDIR_BASE -mindepth 1 -type d -printf '%f\n' | sort | tail -n1`
else
	lastdir=0
fi
startdir=$(( $lastdir + 1 ))
enddir=$(( $startdir + $3 - 1 ))

echo "master bin: $master_bin"
echo "outdir base: $OUTDIR_BASE"

ansible all --become -a "/usr/sbin/insmod /usr/local/bin/fuse-stats.ko"

for i in `seq $startdir $enddir`; do 

    if [ -f stop ]; then
        exit
    fi

    echo "TOP OF LOOP $i ${sc} $1 $2 $3 $4 $5 $#"

    OUTDIR=$OUTDIR_BASE/$i
    echo "outdir: $OUTDIR"
    mkdir -p $OUTDIR

    kubectl apply -f /local/repository/f3/experiments/ffmpeg/yamls/master-pod.yaml
    kubectl apply -f /local/repository/f3/experiments/ffmpeg/yamls/f3-pvc.yaml
    kubectl apply -f /local/repository/f3/experiments/ffmpeg/yamls/ceph-pvc-replicated.yaml
    kubectl wait --for=condition=ready pod mr-master -nopenwhisk --timeout=200s

    #kubectl cp /mnt/local-cache/ffmpeg.tgz mr-master:/var/$sc/ffmpeg.tgz -nopenwhisk
    kubectl cp /local/repository/f3/experiments/ffmpeg/yamls/$master_bin mr-master:/master_v7 -nopenwhisk
    #kubectl exec -n openwhisk mr-master -- tar -mxzvf /var/$sc/ffmpeg.tgz -C /var/$sc/
    kubectl exec -n openwhisk mr-master -- mkdir -p /var/$sc/media_util
    kubectl exec -n openwhisk mr-master -- chmod +x /master_v7

    ansible all --become -mshell -a "echo 1 >/proc/fuse-stats"

    echo -n "$(date +%s)," > $OUTDIR/start_stop
    kubectl exec -n openwhisk mr-master -- /master_v7 $numworkers /var/$sc/media_util /var/$sc/ffmpeg/media_files_4gb/ out /usr/bin/ffmpeg "-f concat -safe 0 -i" "-preset ultrafast -crf 50" "Worker" $sc-pvc /var/$sc >$OUTDIR/output 2>&1
    echo "$(date +%s)," >> $OUTDIR/start_stop

    kubectl get pods -nopenwhisk mr-master --no-headers -o custom-columns=name:metadata.name,node:spec.nodeName > $OUTDIR/pod-nodes
    kubectl get pods -nopenwhisk -luser-action-pod=true --no-headers -o custom-columns=name:metadata.name,node:spec.nodeName >> $OUTDIR/pod-nodes

    # Twice for good luck (...there's a bug, first read sometimes doesn't return anything)
    ansible all -a "cat /proc/fuse-stats" >$OUTDIR/fuse_ops_by_node
    ansible all -a "cat /proc/fuse-stats" >$OUTDIR/fuse_ops_by_node
    agg_ops.py $OUTDIR/fuse_ops_by_node >$OUTDIR/fuse_ops

    ansible all --become -m shell -a "du -ah /mnt/local-cache/tempdir/" | grep -v media_files_4gb >$OUTDIR/cache-contents
    ansible all --become -m shell -a "rm -rf /mnt/local-cache/tempdir/*"
    
    kubectl delete -f /local/repository/f3/experiments/ffmpeg/yamls/master-pod.yaml &
    kubectl delete -f /local/repository/f3/experiments/ffmpeg/yamls/f3-pvc.yaml &
    kubectl delete -f /local/repository/f3/experiments/ffmpeg/yamls/ceph-pvc-replicated.yaml &
    #kubectl delete -f /mnt/local-cache/ffmpeg/yamls/ceph-pvc.yaml &
    kubectl delete pod -luser-action-pod=true -nopenwhisk &
    #timeout 600 kubectl delete -f /local/repository/f3/experiments/f3-only-pvc-replicated.yaml
    until cleanup-pod.sh -luser-action-pod=true -nopenwhisk; do
        echo "Waiting for containers to exit..."
        sleep 60
    done
    #kubectl delete pod owdev-invoker-0 -nopenwhisk
    until cleanup-pod.sh mr-master -nopenwhisk; do
        echo "Waiting for containers to exit..."
        sleep 60
    done
    wait
    #kubectl delete -f /local/repository/f3/experiments/f3-only-pvc-replicated.yaml
    #kubectl delete -f /local/repository/f3/experiments/f3-only-pvc.yaml

    if [ $sc = "f3" ]; then
	    kubectl rollout restart ds csi-f3-node
	    kubectl rollout status ds csi-f3-node --timeout=1200s
    fi

    python3 trim-dstat.py $OUTDIR
done

rm lock
