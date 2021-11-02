#!/bin/bash

before=$(date +%s)
for i in `seq 0 $1`; do
	sed "s/testing-pod/testing-pod-$i/" test-pod.yaml | kubectl apply -f - &
done

echo "All submitted"

while [ `kubectl get pods -nopenwhisk -lapp=stress-test --no-headers | wc -l` -lt $(( $1 + 1 )) ]; do
	sleep 3
done

echo "All starting"

while [ `kubectl get pods -nopenwhisk -lapp=stress-test --no-headers | grep -ic running` -lt $(( $1 + 1 )) ]; do
	sleep 3
done

echo "All running"

after=$(date +%s)
echo $(( $after - $before ))

kubectl delete pods -lapp=stress-test -nopenwhisk
