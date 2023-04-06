#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

# Installation moves files to where they need to go
DEST=$DESTDIR/opt/sensorgnome/cellular
# install in sensorgnome dir
install -d $DEST
install -m 755 *.sh $DEST
# install in system location
install -d $DESTDIR/etc/ModemManager/connection.d $DESTDIR/etc/systemd/system $DESTDIR/etc/udev/rules.d
install -m 644 *.service *.timer $DESTDIR/etc/systemd/system
install -m 755 20-*.mm $DESTDIR/etc/ModemManager/connection.d
install -m 644 *.rules $DESTDIR/etc/udev/rules.d

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb -Zxz --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
