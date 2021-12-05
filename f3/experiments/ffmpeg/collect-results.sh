#!/bin/bash

grep -r "Total Time" results-* | awk '{split($0,a,"-"); split(a[3], b, "/"); print a[2],b[1],$7}' >$1.total_times
find results-* -name output -exec bash -c "grep -H 'Total time to just reduce' {} | head -n1" \; | awk '{split($0,a,"-"); split(a[3], b, "/"); print a[2],b[1],$8}' >$1.reduce_1
find results-* -name output -exec bash -c "grep -H 'Total time to just reduce' {} | tail -n1" \; | awk '{split($0,a,"-"); split(a[3], b, "/"); print a[2],b[1],$8}' >$1.reduce_2
grep -m 1 -r "Total time to just map" results-* | awk '{split($0,a,"-"); split(a[3], b, "/"); print a[2],b[1],$8}' >$1.map_times
