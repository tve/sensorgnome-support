#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

# install sixfab software with adaptions for sensorgnome
# sixfab doesn't tag their release or anything, there's just a v1.9.1 branch, we download a zip
# from github and then extract it to the proper location
# zip for 1.9.1 downloaded with commits from 2022-03-02 1a54db1e8f891a59e1d67e89e0b6399bca22d3bc
DEST=$DESTDIR/opt/sixfab
install -d $DEST
(cd $DEST; unzip -q ../../../core_manager-release-v*.zip)
mv $DEST/core_manager* $DEST/core_manager
(cd $DEST/core_manager; patch -p1 < ../../../core_manager.patch)
install -m644 env.yaml $DEST/.env.yaml
install -m755 eepflash.sh $DEST

install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
mkdir -p packages
dpkg-deb --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
