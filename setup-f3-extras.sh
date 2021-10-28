#!/bin/bash

set -x

if [ -z "$EUID" ]; then
    EUID=`id -u`
fi

# Grab our libs
. "`dirname $0`/setup-lib.sh"

if [ -f $OURDIR/setup-f3-extras-done ]; then
    exit 0
fi

logtstart "f3-extras"

if [ -f $SETTINGS ]; then
    . $SETTINGS
fi
if [ -f $LOCALSETTINGS ]; then
    . $LOCALSETTINGS
fi

echo "alias kc=kubectl" | tee -a ~/.bashrc

if [ ${CENTOS} -eq 0 ] ; then
    $SUDO apt install -y dstat
else
    $SUDO yum install -y dstat
fi

$SUDO mkdir -p /var/log/dstat
($SUDO crontab -l ; echo "@reboot dstat --output /var/log/dstat/stats -T -cdngy 5") | $SUDO crontab -
nohup $SUDO dstat --output /var/log/dstat/stats -T -cdngy 5 >/dev/null 2>&1 &

$SUDO mkdir /var/log/f3

logtend "f3-extras"
touch $OURDIR/setup-f3-extras-done
