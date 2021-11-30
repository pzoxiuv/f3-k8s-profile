#!/bin/bash

#set -o xtrace

if [ -f lock ]; then
    echo "Already running?"
    exit
fi

touch lock

#COUNT=$(( $1 / 4 ))

#FILESIZE=$(( $1 * 1024 * 1024 ))
FILESIZE=`awk -vs=$1 'BEGIN{printf "%.0f", s*1024*1024}'`

ITER=5

MYDIR=`dirname $0`

SC=`echo $2 | cut -d/ -f3`
if [ $SC == "f3" ] && [ `echo $2 | cut -d. -f2` != "id" ]; then SC="f3non"; fi

# 1 = filesize in MB 2 = filepath 3 = append 4 = number readers

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

for i in `seq $5 $6`; do 

    echo "TOP OF LOOP $i ${SC} $1 $4"

    OUTDIR=$MYDIR/$7/e2e-${SC}-$1-$4-readers$3/$i
    mkdir -p $OUTDIR

    kubectl apply -f /local/repository/f3/experiments/f3-only-pvc.yaml
    kubectl apply -f /local/repository/f3/experiments/f3-pod-kubes1.yaml
    #kubectl apply -f /local/repository/f3/experiments/f3-only-pvc-replicated.yaml
    kubectl apply -f deployment.yaml
    kubectl scale deployment f3-testing --replicas=$4 -nopenwhisk
    kubectl rollout status deployment f3-testing -nopenwhisk
    kubectl wait --for=condition=ready pod f3-testing1-pod-kubes1 -nopenwhisk --timeout=200s

    echo -n "$(date +%s)," > $OUTDIR/start_stop

    #pg_read_before=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json 2>/dev/null | tail -n1 | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_read_kb')
    #pg_write_before=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json 2>/dev/null | tail -n1 | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_write_kb')
    kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json > $OUTDIR/pg_stats_before.json
    pg_read_before=`tail -n 1 $OUTDIR/pg_stats_before.json | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_read_kb'`
    pg_write_before=`tail -n 1 $OUTDIR/pg_stats_before.json | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_write_kb'`

    echo "XXX1 $pg_read_before,$pg_write_before"
    echo "AAA1 `kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json | tail -n1 | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_read_kb'`"

    before1=$(($(date +%s%N)/1000000))
    for k in `seq 0 $8`; do
	    kubectl exec f3-testing1-pod-kubes1 -nopenwhisk -- /writer $2/f$k$9 $FILESIZE | tee $OUTDIR/writer
    done
    after1=$(($(date +%s%N)/1000000))
    write_time=$(( $after1 - $before1 ))

    before2=$(($(date +%s%N)/1000000))
    #kubectl get pods -lapp=f3 -nopenwhisk --field-selector=status.phase=Running -o custom-columns=name:metadata.name --no-headers | xargs -I{} bash -c "kubectl exec -nopenwhisk {} -- /reader $2 $FILESIZE > $MYDIR/$7/e2e-${SC}-$1-$4-readers$3/$i/{} &"

    #kubectl get pods -nopenwhisk -lapp=f3 --no-headers -o custom-columns=name:metadata.name,node:spec.nodeName | sort -k2 -u > /tmp/nodelist
    #while read l; do
    #    p=`echo $l | awk '{printf $1}'`
    #    kubectl exec -nopenwhisk $p -- /reader $2 $FILESIZE | tee $OUTDIR/$p &
    #done </tmp/nodelist
    #wait

    #echo "Done first pods"

    #sleep 10

	inode=$(kubectl exec -nopenwhisk f3-testing1-pod-kubes1 -- ls -i $2/f$k$9 | awk '{print $1}')
    counter2=0
    counter=0
	prev_read=`tail -n 1 $OUTDIR/pg_stats.json.$counter2 | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_read_kb'`
    for p in `kubectl get pods -lapp=f3 -nopenwhisk -o custom-columns=name:metadata.name --no-headers`; do
        #if ! `grep -q $p /tmp/nodelist`; then
        for k in `seq 0 $8`; do
                kubectl exec -nopenwhisk $p -- /reader $2/f$k$9 $FILESIZE | tee $OUTDIR/$p.$k &
        done
        #fi
        counter=$(( $counter + 1 ))
        if [ $counter -gt 2 ]; then
            sleep 10
            counter=0
        fi
        counter2=$(( $counter2 + 1 ))
        kubectl exec -nrook-ceph deploy/rook-ceph-tools -- ceph tell mds.cephfs-b dump cache | jq ".[] | select(.ino==$inode) | .client_caps" > $OUTDIR/client-caps.$counter2
        kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json > $OUTDIR/pg_stats.json.$counter2
        cur_read=`tail -n 1 $OUTDIR/pg_stats.json.$counter2 | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_read_kb'`
        echo $(( $(( $cur_read - $prev_read )) / 1024 )) >> $OUTDIR/pg_stats_all
		prev_read=$cur_read
    done
    wait
    after2=$(($(date +%s%N)/1000000))
    read_time=$(( $after2 - $before2 ))

    echo "$(date +%s)," >> $OUTDIR/start_stop

    kubectl get pods -nopenwhisk -lapp=f3 --no-headers -o custom-columns=name:metadata.name,node:spec.nodeName > $OUTDIR/pod-nodes

    echo "$(( $after1 - $before1 )),$(( $after2 - $before2 )),$(( $write_time + $read_time )),$(( $after2 - $before1 )),$i,YYY2" >> $MYDIR/$7/e2e-${SC}-$1-$4-readers$3/timing
    echo "$(( $after1 - $before1 )),$(( $after2 - $before2 )),$(( $write_time + $read_time )),$(( $after2 - $before1 )),$i,YYY2" >> $OUTDIR/timing

    #pg_read_after=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json 2>/dev/null | tail -n1 | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_read_kb')
    #pg_write_after=$(kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json 2>/dev/null | tail -n1 | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_write_kb')
    sleep 60
    kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json > $OUTDIR/pg_stats_after.json
    pg_read_after=`tail -n 1 $OUTDIR/pg_stats_after.json | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_read_kb'`
    pg_write_after=`tail -n 1 $OUTDIR/pg_stats_after.json | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_write_kb'`
    echo "XXX2 $pg_read_after,$pg_write_after"
    echo "AAA2 `kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg dump --format=json | tail -n1 | jq -j -M '.pg_map.pg_stats_sum.stat_sum.num_read_kb'`"

    echo "$(( $pg_read_after - $pg_read_before )),$(( $pg_write_after - $pg_write_before )),${pg_read_before},${pg_read_after},${pg_write_before},${pg_write_after}" >> $OUTDIR/pg_stats

    ansible all -m fetch -a "src=/var/log/f3/cache.stats dest=$OUTDIR/{{ inventory_hostname }}-cache.stats flat=true" --become
    ansible all -m fetch -a "src=/var/log/dstat/stats dest=$OUTDIR/{{ inventory_hostname }}-dstat.stats flat=true" --become

    for j in `seq 2 9`; do
        kubectl logs `kubectl get pod -lapp=csi-f3-node -owide --field-selector spec.nodeName=node-$j --no-headers -o custom-columns=":metadata.name"` -cf3 > $OUTDIR/node-$j-f3.logs
        kubectl logs `kubectl get pod -lapp=csi-f3-node -owide --field-selector spec.nodeName=node-$j --no-headers -o custom-columns=":metadata.name"` -cclient-uds > $OUTDIR/node-$j-client.logs
        kubectl logs `kubectl get pod -lapp=csi-f3-node -owide --field-selector spec.nodeName=node-$j --no-headers -o custom-columns=":metadata.name"` -cserver-uds > $OUTDIR/node-$j-server.logs
        kubectl describe pod `kubectl get pod -lapp=csi-f3-node -owide --field-selector spec.nodeName=node-$j --no-headers -o custom-columns=":metadata.name"` > $OUTDIR/node-$j-desc
    done

    #kubectl exec f3-testing1-pod-kubes1 -nopenwhisk -- yum install -y attr
    #kubectl exec f3-testing1-pod-kubes1 -nopenwhisk -- getfattr -e text -d /var/cephfs/f.id

    for k in `seq 0 $8`; do
	    kubectl exec f3-testing1-pod-kubes1 -nopenwhisk -- rm $2/f$k$9
    done
    ansible all -a "ls -lh /mnt/local-cache/tempdir/" > $OUTDIR/caches
    ansible all --become -m shell -a "rm -rf /mnt/local-cache/tempdir/*"

    kubectl delete -f deployment.yaml
    kubectl delete -f /local/repository/f3/experiments/f3-pod-kubes1.yaml &
    kubectl delete -f /local/repository/f3/experiments/f3-only-pvc.yaml &
    #timeout 600 kubectl delete -f /local/repository/f3/experiments/f3-only-pvc-replicated.yaml
    until cleanup.sh; do
        echo "Waiting for containers to exit..."
        sleep 60
    done
    wait
    #kubectl delete -f /local/repository/f3/experiments/f3-only-pvc-replicated.yaml
    #kubectl delete -f /local/repository/f3/experiments/f3-only-pvc.yaml

    kubectl rollout restart ds csi-f3-node
    kubectl rollout status ds csi-f3-node --timeout=1200s

    python3 /mnt/local-cache/trim-dstat.py $OUTDIR
done

rm lock
