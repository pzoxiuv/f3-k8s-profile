#!/bin/bash

# four runs, one client, one reader per client
./run-single-file.sh f3 f3-nonid 4 1 1 d
./run-single-file.sh f3 f3-nid 4 1 1 d.id
./run-single-file.sh ceph ceph 4 1 1 d

# four runs, three clients, one reader per client
./run-single-file.sh f3 f3-nonid 4 3 1 d
./run-single-file.sh f3 f3-nid 4 3 1 d.id
./run-single-file.sh ceph ceph 4 3 1 d

# four runs, seven clients, one reader per client
./run-single-file.sh f3 f3-nonid 4 7 1 d
./run-single-file.sh f3 f3-nid 4 7 1 d.id
./run-single-file.sh ceph ceph 4 7 1 d

# four runs, one client, five reader per client
./run-single-file.sh f3 f3-nonid 4 1 5 d
./run-single-file.sh f3 f3-nid 4 1 5 d.id
./run-single-file.sh ceph ceph 4 1 5 d

# four runs, three clients, five reader per client
./run-single-file.sh f3 f3-nonid 4 3 5 d
./run-single-file.sh f3 f3-nid 4 3 5 d.id
./run-single-file.sh ceph ceph 4 3 5 d

# four runs, seven clients, five reader per client
./run-single-file.sh f3 f3-nonid 4 7 5 d
./run-single-file.sh f3 f3-nid 4 7 5 d.id
./run-single-file.sh ceph ceph 4 7 5 d
