#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/sg-boot
install -d $DEST
install -m 755 *.sh $DEST
install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system
install -d $DESTDIR/dev/sensorgnome
install -d $DESTDIR/etc/sensorgnome
install -d $DESTDIR/boot
#install -m 644 config-*.txt $DESTDIR/boot # fails trying to make backup
install -m 644 config-*.txt $DEST
install -d $DESTDIR/etc/rsyslog.d
install -m 644 etc-rsyslog.conf $DESTDIR/etc/rsyslog.d/timestamp.conf                               

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb -Zxz --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
