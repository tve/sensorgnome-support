#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

# Set version in version file (goes into /etc/sensorgnome)
DEST=$DESTDIR/etc/sensorgnome
install -d $DEST
TZ=PST8PDT date +'SG %Y-%j' > $DEST/version

# Figure out exact versions of sensorgnome dependencies
cp -r DEBIAN $DESTDIR
# get version of sg-control package 'cause it's not in this repo
wget https://sensorgnome.s3.us-east-2.amazonaws.com/dists/testing/main/binary-armhf/Packages
version=$(egrep -A1 'Package: sg-control' Packages | egrep Version | sort | tail -1 | cut "-d " -f2)
echo "sg-control $version"
sed -ie "s/sg-control/sg-control (>= $version)/" $DESTDIR/DEBIAN/control
# handle local packages
for d in ../packages/*.deb; do
    version=$(echo $d | sed -r -e 's/.*_(.*)_.*/\1/')
    pkg=$(basename $d | sed -e 's/_.*//')
    echo "$pkg: $version"
    sed -ie "s/$pkg/$pkg (>= $version)/" $DESTDIR/DEBIAN/control
done

echo ""
echo "sensorgnome package control file:"
cat $DESTDIR/DEBIAN/control
echo ""

# Boilerplate package generation
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
