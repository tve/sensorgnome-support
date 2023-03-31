#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/upgrader
install -d $DEST $DEST/sources $DEST/bail-me-out
install -m 755 *.sh $DEST
install -m 644 sources/* $DEST/sources
install -m 755 bail-me-out/* $DEST/bail-me-out

# logrotate control file
sudo install -d $DESTDIR/etc/logrotate.d
sudo install -m 644 upgrade.rotate $DESTDIR/etc/logrotate.d/upgrade

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb -Zxz --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
