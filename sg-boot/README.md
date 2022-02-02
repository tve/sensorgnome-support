Sensorgnome Boot Basics
=======================

Scripts to set-up a few general basics on the sensorgnome before everything else is unleashed:

- set-up sensorgnome ID in /etc/sensorgnome/id
- set-up hostname
- create a FAT32 partition for /data if there isn't one and there's space
- increment a boot counter

Dev notes
---------

(See also top-level README.)

The `sg-boot.deb` package can be installed and tested on a vanilla rPi with the following
considerations:

- to exercise the /data partition creation /data must be located on the root device and
  there must be empty space on the "root" SDcard
- if /data on the root partition contains files, they should be moved over to the new
  partition automatically
- you can typically revert a run of `sg-boot` as follows:

```bash
  sudo umount /data
  sudo parted /dev/mmcblk0 rm 3
  sudo vi /etc/fstab # manually delete the data partition
```
