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

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
mkdir -p packages
dpkg-deb --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
