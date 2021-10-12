#!/bin/bash

sudo tc qdisc del root dev ens160
ansible 'all:!kubes1' -m shell --become  --extra-vars '@/home/alex/test.yml' -a "/usr/sbin/tc qdisc del root dev eno16777984"
