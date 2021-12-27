#!/bin/bash

# four runs, one client, one reader per client
#./run-tar.sh f3 f3-nonid 3 1 1 d
#./run-tar.sh f3 f3-id 3 1 1 d.id
#./run-tar.sh ceph ceph 3 1 1 d

# four runs, three clients, one reader per client
./run-tar.sh f3 f3-nonid 3 3 1 d
./run-tar.sh f3 f3-id 3 3 1 d.id
./run-tar.sh ceph ceph 3 3 1 d

# four runs, seven clients, one reader per client
./run-tar.sh f3 f3-nonid 3 7 1 d
./run-tar.sh f3 f3-id 3 7 1 d.id
./run-tar.sh ceph ceph 3 7 1 d

# four runs, one client, five reader per client
./run-tar.sh f3 f3-nonid 3 1 5 d
./run-tar.sh f3 f3-id 3 1 5 d.id
./run-tar.sh ceph ceph 3 1 5 d

# four runs, three clients, five reader per client
./run-tar.sh f3 f3-nonid 3 3 5 d
./run-tar.sh f3 f3-id 3 3 5 d.id
./run-tar.sh ceph ceph 3 3 5 d

# four runs, seven clients, five reader per client
./run-tar.sh f3 f3-nonid 3 7 5 d
./run-tar.sh f3 f3-id 3 7 5 d.id
./run-tar.sh ceph ceph 3 7 5 d
