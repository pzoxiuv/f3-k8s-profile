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

if [ -n "$ENABLECEPH" -a $ENABLECEPH -eq 1 ]; then
	cd $SRC/ceph
	kubectl apply -f crds.yaml -f common.yaml -f operator.yaml
	sleep 10
	kubectl apply -f cluster.yaml -f filesystem.yaml -f storageclass.yaml -f filesystem-replicated.yaml -f storageclass-replicated.yaml
	cd $SRC
fi

$SUDO apt install -y ansible
echo "node-[0:9]" | $SUDO tee -a /etc/ansible/hosts

for i in `seq 1 9`; do ssh-keygen -R node-$i; ssh-keyscan -H node-$i >> ~/.ssh/known_hosts ; done

if [ -n "$SHARESSD" -a $SHARESSD -eq 1 ]; then
	ansible all -m shell -a "printf 'n\np\n1\n2048\n468851543\nw\n' | fdisk /dev/sdc" --become
	ansible all -m shell -a "printf 'n\np\n2\n468852736\n937703087\nw\n' | fdisk /dev/sdc" --become
	ansible all -m shell -a "mkfs.ext4 /dev/sdc1" --become
	ansible all -m shell -a "mount /dev/sdc1 /mnt/local-cache/tempdir" --become

	cd $SRC/ceph
	kubectl apply -f crds.yaml -f common.yaml -f operator.yaml
	sleep 10
	kubectl apply -f cluster-sharedssd.yaml -f filesystem.yaml -f storageclass.yaml
	cd $SRC
fi

cd $SRC/nfs-all
kubectl apply -f rbac.yaml -f provisioner.yaml -f sc.yaml
kubectl patch storageclass all-nfs -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
cd $SRC

cd $SRC/openwhisk-deploy-kube
kubectl label node  openwhisk-role=invoker --all
helm install owdev ./helm/openwhisk -n openwhisk --create-namespace -f mycluster.yaml
kubectl apply -f rbac.yaml
$SUDO mv wsk /usr/local/bin/
wsk property set --apihost 10.10.1.1:31001 --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP"
cd $SRC

cd $SRC/f3/csi
make local-k8s-install
cd $SRC

cd $SRC/f3
wsk -i action create cmd openwhisk/actions/cmd.py
wsk -i action update cmd --timeout 1200
wsk -i action update cmd --memory 1024
cd $SRC

logtend "f3"
touch $OURDIR/setup-f3-done
