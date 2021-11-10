#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/udev-usb
install -d $DEST
install -m 755 usb-init.sh get-usb-port.py get-hub-devices.py $DEST
install -m 644 *.txt $DEST
install -d $DESTDIR/etc/udev/rules.d
install -m 644 20-usb-hub-devices.rules $DESTDIR/etc/udev/rules.d
install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
mkdir -p packages
dpkg-deb --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
