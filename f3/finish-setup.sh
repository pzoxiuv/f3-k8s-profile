#!/bin/bash

pushd /local/repository/f3/fuse/stats-mod/
make
make install
popd

wsk -i action create Worker /local/repository/f3/experiments/ffmpeg/yamls/worker_v3.go --timeout 1800000 --memory 10000
