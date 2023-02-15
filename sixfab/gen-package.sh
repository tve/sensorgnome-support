#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR
SRC=$PWD

# install sixfab software with adaptions for sensorgnome
# sixfab doesn't tag their release or anything, there's just a v1.9.1 branch, we download a zip
# from github and then extract it to the proper location
# zip for 1.9.1 downloaded with commits from 2022-03-02 1a54db1e8f891a59e1d67e89e0b6399bca22d3bc
DEST=$DESTDIR/opt/sixfab
install -d $DEST
(cd $DEST; unzip -q $SRC/core_manager-release-v*.zip)
mv $DEST/core_manager* $DEST/core_manager
(cd $DEST/core_manager; patch -p1 < $SRC/core_manager.patch)
install -m644 env.yaml $DEST/.env.yaml
install -m755 eepflash.sh postinstall.sh $DEST

# install sixfab UPS HAT python lib (SHA 04a9624 is V1 release)
DEST2=$DESTDIR/opt/sensorgnome/ups-hat
install -d $DEST2
# curl -L https://github.com/sixfab/sixfab-power-python-api/archive/04a9624.tar.gz | \
#     tar -C $DEST2 -zxf -
wget https://github.com/sixfab/sixfab-power-python-api/archive/refs/heads/master.zip
unzip master.zip sixfab-power-python-api-master/power_api/
rm master.zip
mv sixfab-power-python-api-master/power_api $DEST2
rmdir sixfab-power-python-api-master

install -m 755 ups_manager.py $DEST2

install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system
install -d $DESTDIR/etc/udev/rules.d
install -m 644 *.rules $DESTDIR/etc/udev/rules.d

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb -Zxz --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
