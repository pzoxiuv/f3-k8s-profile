#!/bin/bash

set -x

if [ -z "$EUID" ]; then
    EUID=`id -u`
fi

# Grab our libs
. "`dirname $0`/setup-lib.sh"

if [ -f $OURDIR/setup-f3-done ]; then
    exit 0
fi

logtstart "f3"

if [ -f $SETTINGS ]; then
    . $SETTINGS
fi
if [ -f $LOCALSETTINGS ]; then
    . $LOCALSETTINGS
fi

cd $SRC/ceph
kubectl apply -f crds.yaml -f common.yaml -f operator.yaml
kubectl apply -f cluster.yaml
kubectl apply -f filesystem-test.yaml
kubectl apply -f csi/cephfs/storageclass.yaml
cd $SRC

cd $SRC/nfs-all
kubectl apply -f rbac.yaml -f provisioner.yaml -f sc.yaml
kubectl patch storageclass all-nfs -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
cd $SRC

cd $SRC/openwhisk-deploy-kube
kubectl label node  openwhisk-role=invoker --all
helm install owdev ./helm/openwhisk -n openwhisk --create-namespace -f mycluster.yaml
cd $SRC

cd $SRC/f3/csi
make local-k8s-install
cd $SRC

logtend "f3"
touch $OURDIR/setup-f3-done
