#!/bin/bash

kubectl delete -f /local/repository/f3/experiments/ffmpeg/yamls/master-pod.yaml &
kubectl delete -f /local/repository/f3/experiments/ffmpeg/yamls/f3-pvc.yaml &
kubectl delete -f /local/repository/f3/experiments/ffmpeg/yamls/minio-pvc.yaml &
kubectl delete -f /local/repository/f3/experiments/ffmpeg/yamls/ceph-pvc-replicated.yaml &
kubectl delete pod -luser-action-pod=true -nopenwhisk &

if [ $# -gt 0 ]; then
    ansible all --become -m shell -a "rm -rf /mnt/local-cache/tempdir/*"
    kubectl rollout restart ds csi-f3-node
    kubectl rollout status ds csi-f3-node
fi

wait
