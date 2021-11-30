#!/bin/bash

ret=0

all_containers=$(ansible all -a "ctr -n k8s.io c ls -q" --become | grep "^[0-9a-f].*$")
for pod in `kubectl get pods -lapp=f3 -nopenwhisk -oname`; do
	found=0
	for container in `kubectl get $pod -nopenwhisk -ojsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.containerID}{"\n"}{end}' | cut -d/ -f3`; do
		echo $all_containers | grep -q $container
		if [ $? == 0 ]; then
			found=1
			ret=1
			echo "Found container $container of pod $pod still running"
		fi
	done
	if [ $found == 0 ]; then
		kubectl delete $pod -nopenwhisk --force --grace-period=0
	fi
done

found=0
for container in `kubectl get pod f3-testing1-pod-kubes1 -nopenwhisk -ojsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.containerID}{"\n"}{end}' | cut -d/ -f3`; do
	echo $all_containers | grep -q $container
	if [ $? == 0 ]; then
		found=1
		ret=1
		echo "Found container $container of pod f3-testing1-pod-kubes1 still running"
	fi
done

if [ $found == 0 ]; then
	kubectl delete pod f3-testing1-pod-kubes1 -nopenwhisk --force --grace-period=0
fi

found=0
for container in `kubectl get pod -lf3.role=target-pod -nopenwhisk -ojsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.containerID}{"\n"}{end}' | cut -d/ -f3`; do
	echo $all_containers | grep -q $container
	if [ $? == 0 ]; then
		found=1
		ret=1
		echo "Found container $container of pod target pod still running"
	fi
done

if [ $found == 0 ]; then
	kubectl delete pod -lf3.role=target-pod -nopenwhisk --force --grace-period=0
fi

exit $ret
