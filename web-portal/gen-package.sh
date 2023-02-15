#! /bin/bash -e
DESTDIR=build-temp
rm -rf $DESTDIR
mkdir $DESTDIR

# npm install to populate modules
npm --no-fund install

DEST=$DESTDIR/opt/sensorgnome/web-portal
install -d $DEST
install -m 644 Caddyfile $DEST
install -m 755 *.sh $DEST
install -m 644 *.js *.txt *.json $DEST
cp -r node_modules $DEST
install -d $DEST/public
install -m 644 *.html  $DEST/public
install -d $DESTDIR/etc/systemd/system
install -m 644 *.service $DESTDIR/etc/systemd/system

# Fetch local-ip HTTPS certs - this is duplicated in the sensorgnome image build pifile
# They also get updated from the SG Hub.
install -d $DESTDIR/etc/sensorgnome
# install -m 644 local-ip.key $DESTDIR/etc/sensorgnome
# cat local-ip.pem local-ip-chain.pem >$DESTDIR/etc/sensorgnome/local-ip.pem
curl -L -o $DESTDIR/etc/sensorgnome/local-ip.key http://local-ip.co/cert/server.key
curl -L -o $DESTDIR/etc/sensorgnome/local-ip.pem http://local-ip.co/cert/server.pem
curl -L -o - http://local-ip.co/cert/chain.pem >> $DESTDIR/etc/sensorgnome/local-ip.pem
chmod 644 $DESTDIR/etc/sensorgnome/local-ip.*

# Boilerplate package generation
cp -r DEBIAN $DESTDIR
sed -e "/^Version/s/:.*/: $(TZ=PST8PDT date +%Y.%j)/" -i $DESTDIR/DEBIAN/control # set version: YYYY.DDD
dpkg-deb --root-owner-group --build $DESTDIR ../packages
# dpkg-deb --contents ../packages
ls -lh ../packages
