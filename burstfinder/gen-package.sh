#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/burstfinder
install -d $DEST
install -m 644 bursts src/LICENSE $DEST
sed <src/burstfinder.py >$DEST/burstfinder.py \
    -e '/^logging/s/%(asctime)s - //' \
    -e 's/, logging.FileHandler('burstfinder.log')//'

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb -Zxz --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
