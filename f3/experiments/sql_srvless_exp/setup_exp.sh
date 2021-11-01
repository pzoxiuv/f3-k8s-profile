#!/bin/bash

if [ -f wsk ]
then
    echo "Adding wsk cli to /usr/local/bin"
    sudo mv wsk /usr/local/bin/
else
    echo "Already added wsk cli to /usr/local/bin"
fi

if ! [ -f ran_already ]
then
    echo "Installing sqlite3 and numpy"
    sudo apt-get install sqlite3
    pip install numpy
fi

WSK_HOSTNAME="$(grep 'apiHostName:' /local/repository/openwhisk-deploy-kube/mycluster.yaml | awk '{print $2}' | sed -e 's|["'\'']||g')"
WSK_HOSTPORT="$(grep 'apiHostPort:' /local/repository/openwhisk-deploy-kube/mycluster.yaml | awk '{print $2}' | sed -e 's|["'\'']||g')"
WSK_AUTH="$(grep 'guest:' /local/repository/openwhisk-deploy-kube/mycluster.yaml | awk '{print $2}' | sed -e 's|["'\'']||g')"

if ! [ -f ran_already ]
then
    echo "Setting properties for wsk cli..."
    echo "Setting wsk apihost to $WSK_HOSTNAME:$WSK_HOSTPORT"
    echo "Setting wsk auth to $WSK_AUTH"
    wsk property set —-apihost $WSK_HOSTNAME:$WSK_HOSTPORT && wsk property set --auth $WSK_AUTH
else
    echo "wsk cli properties already set"
fi

if ! [ -f ran_already ]
then
    echo "Generating database..."
    cd tpch-sqlite/dbgen-script
    make SCALE_FACTOR=2
    echo "Done generating database."
    cd ../../
else
    echo "Database already generated."
fi

if ! [ -f ran_already ]
then
    echo "Creating PVC..."
    kubectl apply -f pvc.yaml
    #while [[ $(kubectl -nopenwhisk get pvc sql-nfs-nfs-pvc -o 'jsonpath={..status.phase}') != "Bound"]]
    #do
    #  echo "waiting for PVC to be bound" && sleep 1; done
    echo "Creating busybox pod and copying database files to nfs PV"
    kubectl apply -f busypod.yaml
    kubectl wait --for=condition=ready pod busybox -nopenwhisk --timeout=30s
    kubectl -nopenwhisk cp ./tpch-sqlite/tpch-bkp/TPC-H.db busybox:/mydata/
    kubectl -nopenwhisk cp ./tpch-sqlite/tpch-bkp/queries.sql busybox:/mydata

    echo "Creating serverpod..."
    kubectl apply -f sqlservertime.yaml
    kubectl wait --for=condition=ready pod sqlservertime -nopenwhisk --timeout=30s

    echo "Creating openwhisk web action..."
    wsk -i action create sqlactiontime sqlactiontime.py --memory 256 --timeout 200000 --param f3SeqId sql-nfs --web true
else
    echo "PVC,PV, serverpod, and action already created."
fi

if ! [ -f ran_already ]
then
    echo "Configuring haproxy pods"
    echo "  server sqlactiontime $WSK_HOSTNAME:$WSK_HOSTPORT ssl verify none" >> haproxy/srvless.cfg
    kubectl -nopenwhisk create configmap haproxy-srvless-config --from-file=./haproxy/srvless.cfg
    kubectl apply -f ./haproxy/haproxypod_srvless.yaml
    kubectl wait --for=condition=ready pod haproxypod-srvless -nopenwhisk --timeout=30s
    echo "HAProxy srvless pod is setup."

    kubectl -nopenwhisk create configmap haproxy-srvfull-config --from-file=./haproxy/srvfull.cfg
    kubectl apply -f ./haproxy/haproxypod_srvfull.yaml
    kubectl wait --for=condition=ready pod haproxypod-srvfull -nopenwhisk --timeout=30s
    echo "HAProxy srvfull pod is setup."
else
    echo "HAProxy already setup"
fi

echo "Experiment setup is done"

touch ran_already