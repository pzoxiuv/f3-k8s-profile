#!/bin/sh

set -x

ALLNODESCRIPTS="setup-ssh.sh setup-disk-space.sh setup-f3-extras.sh"
HEADNODESCRIPTS="setup-nfs-server.sh setup-nginx.sh setup-ssl.sh setup-kubespray.sh setup-kubernetes-extra.sh setup-f3.sh setup-end.sh"
WORKERNODESCRIPTS="setup-nfs-client.sh"

bash -c "cd /local/repository; git submodule init; git submodule update; git clone --recurse-submodules https://github.com/pzoxiuv/f3.git"

export SRC=`dirname $0`
cd $SRC
. $SRC/setup-lib.sh

# Don't run setup-driver.sh twice
if [ -f $OURDIR/setup-driver-done ]; then
    echo "setup-driver already ran; not running again"
    exit 0
fi
for script in $ALLNODESCRIPTS ; do
    cd $SRC
    $SRC/$script | tee - $OURDIR/${script}.log 2>&1
done
if [ "$HOSTNAME" = "node-0" ]; then
    for script in $HEADNODESCRIPTS ; do
	cd $SRC
	$SRC/$script | tee - $OURDIR/${script}.log 2>&1
    done
	echo "if [ -n \$MYPID ] && [ "\$TERM" != "dumb" ] && [ -z "\$STY" ]; then screen -dRRS \$MYPID; fi" | tee -a ~/.bashrc
	echo "AcceptEnv MYPID" | $SUDO tee -a /etc/ssh/sshd_config
	$SUDO service sshd restart
else
    for script in $WORKERNODESCRIPTS ; do
	cd $SRC
	$SRC/$script | tee - $OURDIR/${script}.log 2>&1
    done
fi

exit 0
