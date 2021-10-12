#!/bin/bash

kubectl exec -nopenwhisk testing1-pod-kubes1 -- rm /var/f3/*
kubectl exec -nopenwhisk testing1-pod-kubes1 -- rm /var/minio/*
kubectl exec -nopenwhisk testing1-pod-kubes1 -- rm /var/ceph/*
kubectl exec -nopenwhisk testing1-pod-kubes1 -- rm /var/nfs/*

ansible kubes1,kubes3 --become --ask-become-pass -m shell -a "rm -rf /mnt/local-cache/tempdir/*"

kubectl delete -nopenwhisk pod testing1-pod-kubes1 testing1-pod-kubes3
