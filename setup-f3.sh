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

PREVDIR=`pwd`
SRC=/local/repository
if [ -n "$ENABLECEPH" -a $ENABLECEPH -eq 1 ]; then
	cd $SRC/ceph
	./create-osd-pvs.sh
	kubectl apply -f crds.yaml -f common.yaml -f operator.yaml
	sleep 10
	if [ -n "$SHARESSD" -a $SHARESSD -eq 1 ]; then
		kubectl apply -f cluster-sharedssd.yaml
	else
		kubectl apply -f cluster.yaml
	fi
	kubectl apply -f filesystem.yaml -f storageclass.yaml -f filesystem-replicated.yaml -f storageclass-replicated.yaml
	cd $PREVDIR
fi

maybe_install_packages ansible
echo "node-[0:9]" | $SUDO tee -a /etc/ansible/hosts

for i in `seq 1 9`; do ssh-keygen -R node-$i; ssh-keyscan -H node-$i >> ~/.ssh/known_hosts ; done

kubectl cordon $ETCD_NODE

cd $SRC/nfs-all
kubectl apply -f rbac.yaml -f provisioner.yaml -f sc.yaml -f nfs-nfs-pvc.yaml
kubectl patch storageclass all-nfs -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
cd $PREVDIR

cd $SRC/openwhisk-deploy-kube
kubectl label node  openwhisk-role=invoker --all
helm install owdev ./helm/openwhisk -n openwhisk --create-namespace -f mycluster.yaml
kubectl apply -f rbac.yaml
kubectl apply -f map-reduce-master.yaml
$SUDO cp wsk /usr/local/bin/
wsk property set --apihost 10.10.1.2:31001 --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP"
cd $PREVDIR

cd $SRC/f3/csi
make local-k8s-install
cd $PREVDIR

cd $SRC/f3
wsk -i action create cmd openwhisk/actions/cmd.py
wsk -i action update cmd --timeout 1200000
wsk -i action update cmd --memory 1024
cd $PREVDIR

cd $SRC/f3/utils
$SUDO cp cleanup.sh /usr/local/bin/
$SUDO chmod +x /usr/local/bin/cleanup.sh
cd $PREVDIR

maybe_install_packages screen jq

logtend "f3"
touch $OURDIR/setup-f3-done
