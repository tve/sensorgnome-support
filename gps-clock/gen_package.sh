#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/gps-clock
install -d $DEST $DESTDIR/etc/chrony
install -m 644 boot-config.txt $DEST
install -m 644 chrony.conf $DESTDIR/etc/chrony
install -d $DESTDIR/etc/systemd/system/chrony.service.d
install -m 644 chrony-override.conf $DESTDIR/etc/systemd/system/chrony.service.d/restart.conf
install -m 644 sg-gps-link.service $DESTDIR/etc/systemd/system

cp -r DEBIAN $DESTDIR
dpkg-deb -v --build $DESTDIR sg-gps-clock.deb
# dpkg-deb --contents sg-gps-clock.deb
ls -lh sg-gps-clock.deb
