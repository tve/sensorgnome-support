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
# wget https://sensorgnome.s3.us-east-2.amazonaws.com/dists/testing/main/binary-armhf/Packages
# deps=$(awk -v ORS= '/^Depends:/,/[^,]$/' DEBIAN/control | sed -e 's/^\S*://' -e 's/ *, */ /g')
# echo "Versions found in repo:"
# for d in $deps; do
#     version=$(awk '/^Package:/{pkg=$2} /^Version/&&pkg=="'$d'"{print $2}' Packages | sort | tail -1)
#     echo "$d: $version"
#     sed -ie "s/$d/$d (>= $version)/" $DESTDIR/DEBIAN/control
# done
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
mkdir -p packages
dpkg-deb --root-owner-group --build $DESTDIR packages
# dpkg-deb --contents ../packages
ls -lh packages
