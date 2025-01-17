#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/hub-agent
install -d $DEST
install -m 755 *.sh *.js $DEST
install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system
install -d $DESTDIR/etc/telegraf
install -m 755 telegraf.conf $DESTDIR/etc/telegraf/telegraf.new
mkdir -p $DESTDIR/etc/apt/trusted.gpg.d
gpg --dearmor -o $DESTDIR/etc/apt/trusted.gpg.d/influxdb.gpg <influxdata-archive_compat.key

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb -Zxz --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
