#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/gps-clock
install -d $DEST $DESTDIR/etc/chrony $DESTDIR/dev/sensorgnome
install -m 644 boot-config.txt $DEST
install -m 755 init-gps.sh $DEST
install -m 644 chrony.conf $DESTDIR/etc/chrony
install -d $DESTDIR/etc/systemd/system/chrony.service.d
install -m 644 chrony-override.conf $DESTDIR/etc/systemd/system/chrony.service.d/restart.conf
install -m 644 sg-gps-init.service $DESTDIR/etc/systemd/system

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)d/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
mkdir -p packages
dpkg-deb --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
