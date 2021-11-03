#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

DEST=$DESTDIR/opt/sensorgnome/udev-usb
install -d $DEST
install -m 755 usb-init.sh get-usb-port.py $DEST
install -m 644 *.txt $DEST
install -d $DESTDIR/etc/udev/rules.d
install -m 644 20-usb-hub-devices.rules $DESTDIR/etc/udev/rules.d
install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system

cp -r DEBIAN $DESTDIR
dpkg-deb -v --build $DESTDIR sg-udev-usb.deb
# dpkg-deb --contents sg-udev-usb.deb
ls -lh sg-udev-usb.deb
