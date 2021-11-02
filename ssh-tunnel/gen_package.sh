#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/.ssh
# obfuscate keys so they're not easily detectable by bots that scan github repos
install -m 700 -d $DEST
tr '\!-~' 'P-~\!-O' <factory >$DEST/id_dsa_factory
tr '\!-~' 'P-~\!-O' <factory-pub >$DEST/id_dsa_factory.pub
touch $DEST/authorized_keys
chmod 700 $DEST
chmod 600 $DEST/*

DEST=$DESTDIR/opt/sensorgnome/ssh-tunnel

install -d $DEST
install -m 755 *.sh $DEST
install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system

cp -r DEBIAN $DESTDIR
dpkg-deb -v --build $DESTDIR sg-ssh-tunnel.deb
# dpkg-deb --contents sg-ssh-comms.deb
ls -lh sg-ssh-tunnel.deb
