#! /bin/bash -e
rm -rf build-temp
mkdir build-temp
make DESTDIR=build-temp install
cp -r DEBIAN build-temp
dpkg-deb -v --build build-temp sg-wifi-button.deb
# dpkg-deb --contents wifi-button.deb
ls -lh sg-wifi-button.deb
