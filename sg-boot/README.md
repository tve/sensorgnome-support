Sensorgnome Boot Basics
=======================

Scripts to set-up a few general basics on the sensorgnome before everything else is unleashed:
- set-up sensorgnome ID in /etc/sensorgnome_id
- set-up hostname
- create a FAT32 partition for /data if there isn't one and there's space
- increment a boot counter

Development
-----------

The `sg-boot` package can be built using the `gen_package.sh` script. It requires a couple of
debian tools so it's best run inside of a dockcross container. Assuming you have `sensorgnome-build`
checked-out alongside this repo this might look as follows:
```
../../sensorgnome-build/docker/sensorgnome-armv7-rpi-buster ./gen_package.sh
```

The `sg-boot.deb` package can be installed and tested on a vanilla rPi with the following
considerations:
- to exercise the /data partition creation /data must be located on the root device and
  there must be empty space on the "root" SDcard
- if /data on the root partition contains files, they should be moved over to the new
  partition automatically
- you can typically revert a run of `sg-boot` as follows:
```
sudo umount /data
sudo parted /dev/mmcblk0 rm 3
sudo vi /etc/fstab # manually delete the data partition
```

For test&dev the `doit` script can be used to generate a fresh package, upload it to a nearby
rPi, install it, and restart appropriate services. It assumes that the
`sensorgnome-armv7-rpi-buster` dockcross script/image is available and it has a hardcoded
rPi hostname that you will need to adapt. (You will also want to set your rPi up with ssh
key-based auth so you don't have to type a password 10 times...)
