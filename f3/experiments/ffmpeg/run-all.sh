#!/bin/bash

#./run.sh ceph results 5 1
#./run.sh ceph results 5 10
#./run.sh ceph results 5 30
#./run.sh ceph results 5 50
#./run.sh ceph results 5 70
#
#./run.sh f3 results 5 1
#./run.sh f3 results 5 10
#./run.sh f3 results 5 30
#./run.sh f3 results 5 50
#./run.sh f3 results 5 70
#
#./run.sh f3 results 5 1 y
#./run.sh f3 results 5 10 y
#./run.sh f3 results 5 30 y
#./run.sh f3 results 5 50 y
#./run.sh f3 results 5 70 y

./run.sh ceph results 5 50 ceph
./run.sh f3 results 5 50 f3non
./run.sh f3 results 5 50 f3 y
