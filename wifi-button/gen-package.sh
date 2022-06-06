#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

make # produces dtbo

# Installation moves files to where they need to go
DEST=$DESTDIR/opt/sensorgnome/wifi-button
# install in sensorgnome dir
install -d $DEST
install -m 644 *.js $DEST
install -m 755 *.sh $DEST
install -m 644 gpio_pull.dtbo $DEST
install -m 644 *.txt $DEST
install -m 644 etc-dhcpcd.conf $DEST
install -m 644 etc-hostapd.conf $DEST
# install in system location
install -d $DESTDIR/etc/hostapd $DESTDIR/etc/systemd/system $DESTDIR/etc/dnsmasq.d
install -d $DESTDIR/boot $DESTDIR/boot/overlays
install -m 644 *.service $DESTDIR/etc/systemd/system
install -m 644 etc-dnsmasq.conf $DESTDIR/etc/dnsmasq.d/wifi-button.conf
#install -m 644 etc-wpa_supplicant.conf $DESTDIR/etc/wpa_supplicant/wpa_supplicant.conf

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
mkdir -p packages
dpkg-deb --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
