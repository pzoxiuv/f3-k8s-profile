#!/bin/bash

kubectl delete -f /local/repository/f3/experiments/scaling/writer.yaml &
kubectl delete -f /local/repository/f3/experiments/scaling/reader-3.yaml &
kubectl delete -f /local/repository/f3/experiments/scaling/reader-4.yaml &
kubectl delete -f /local/repository/f3/experiments/scaling/f3-pvc.yaml &
#kubectl delete -f /local/repository/f3/experiments/scaling/minio-pvc.yaml
kubectl delete -f /local/repository/f3/experiments/scaling/ceph-pvc-replicated.yaml &
until cleanup-pod.sh writer -nopenwhisk; do
    echo "Waiting for containers to exit..."
    sleep 60
done
until cleanup-pod.sh reader-3 -nopenwhisk; do
    echo "Waiting for containers to exit..."
    sleep 60
done
until cleanup-pod.sh reader-4 -nopenwhisk; do
    echo "Waiting for containers to exit..."
    sleep 60
done
wait

if [ $# -gt 0 ]; then
	    ansible all --become -m shell -a "rm -rf /mnt/local-cache/tempdir/*"
	    kubectl rollout restart ds csi-f3-node
	    kubectl rollout status ds csi-f3-node --timeout=1200s
fi
