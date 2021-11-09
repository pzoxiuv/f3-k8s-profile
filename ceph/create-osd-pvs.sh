#!/bin/bash

cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: manual
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

for node in `kubectl get nodes --no-headers | awk '!/master/{print $1}'`; do
	cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $node-cephvol-pv
spec:
  storageClassName: manual
  capacity:
    storage: 223Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  volumeMode: Block
  local:
    path: /dev/ssd/cephvol
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
              - $node
EOF
done

count=`kubectl get nodes --no-headers | grep -vc master`
yq -i e '.spec.storage.storageClassDeviceSets[] |= select(.name == "set1").count='$count cluster-sharedssd.yaml
