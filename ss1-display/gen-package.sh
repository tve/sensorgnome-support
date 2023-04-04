#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/ss1-display
install -d $DEST $DEST/inky-phat
install -m 755 *.sh *.py $DEST
install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system
ls
ls $DEST
cp -r inky-phat/library $DEST/inky-phat

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb -Zxz --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
