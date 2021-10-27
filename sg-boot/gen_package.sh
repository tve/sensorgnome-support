#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/sg-boot
install -d $DEST
install -m 755 *.sh $DEST
install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system

cp -r DEBIAN $DESTDIR
dpkg-deb -v --build $DESTDIR sg-boot.deb
# dpkg-deb --contents sg-boot.deb
ls -lh sg-boot.deb
