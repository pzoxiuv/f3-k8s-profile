#!/bin/bash

sudo tc qdisc del root dev ens192
sudo tc qdisc del root dev ifb0
ansible 'all:!kubes1' -m shell --become  --extra-vars '@/home/alex/test.yml' -a "/usr/sbin/tc qdisc del root dev eno33557248"
ansible 'all:!kubes1' -m shell --become  --extra-vars '@/home/alex/test.yml' -a "/usr/sbin/tc qdisc del root dev ifb0"
