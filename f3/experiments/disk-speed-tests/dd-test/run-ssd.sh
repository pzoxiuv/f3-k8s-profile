#!/bin/bash

if [ -f lock ]; then
    echo "Already running?"
    exit
fi

touch lock

COUNT=$(( $1 / 4 ))

ITER=2

MYDIR=`dirname $0`

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

for i in `seq 0 $ITER`; do
    {
    date
    echo "AAA" `date +%s`

    sudo -u amerenst ssh node-1 sudo /local/repository/f3/experiments/disk-speed-tests/dd-test/do-write-test.sh $i $COUNT

    echo "---"
    } >> $MYDIR/write-f3-$1$2 2>&1

    {
    date
    echo "AAA" `date +%s`

    sudo -u amerenst ssh node-1 sudo /local/repository/f3/experiments/disk-speed-tests/dd-test/do-write-direct-test.sh $i $COUNT

    echo "---"
    } >> $MYDIR/write-direct-f3-$1$2 2>&1

    {
    date
    echo "AAA" `date +%s`

    sudo -u amerenst ssh node-1 sudo /local/repository/f3/experiments/disk-speed-tests/dd-test/do-read-test.sh $i $COUNT

    echo "---"
    } >> $MYDIR/read-f3-$1$2 2>&1

    {
    date
    echo "AAA" `date +%s`

    sudo -u amerenst ssh node-1 sudo /local/repository/f3/experiments/disk-speed-tests/dd-test/do-read-direct-test.sh $i $COUNT

    echo "---"
    } >> $MYDIR/read-direct-f3-$1$2 2>&1

done

rm lock
