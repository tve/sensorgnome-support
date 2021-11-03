#! /bin/bash -e
# Initialize a development rPi with "my" stuff.
# This is not a way to make sensorgnome releases (use the sensorgnome-build repo for this).
# The intent of this script is to be able to flash an SDcard with the official rPi lite OS image,
# initialize the image with some SSH creds and some additional tweaks so it can be used to test and
# dev the debian services in this repo. I.e., to make the "doit" scripts found in each subdir work.

SSH_KEY=tve-2016.pub # name of the ssh public key file in $HOME/.ssh to put on the pi
SG_NAME=sg-eth.voneicken.com # host name (or IP address) of the pi on the local network

rootfs=$(findmnt -A -l -n -t ext4,vfat | egrep '/rootfs\s' | cut -f1 -d " ")
if [[ -z "$rootfs" ]]; then
  echo "Cannot locate rootfs"
  exit 1
fi
if [[ ! -d $rootfs/home/pi ]]; then
  echo "Rootfs at $rootfs doesn't seem to be rPi image"
  exit 1
fi
echo "Rootfs at $rootfs"

bootfs=$(sed -e "s/rootfs/boot/" <<<$rootfs)
if [[ ! -f $bootfs/config.txt ]]; then
  echo "Bootfs at $bootfs doesn't seem to be rPi image"
  exit 1
fi
echo "Bootfs at $bootfs"

# enable ssh daemon
touch $bootfs/ssh

# copy ssh key
mkdir -p $rootfs/home/pi/.ssh
chmod 700 $rootfs/home/pi/.ssh
cp $HOME/.ssh/$SSH_KEY $rootfs/home/pi/.ssh/authorized_keys
sudo chown -R 1000 $rootfs/home/pi/.ssh || echo "Oops, can't give .ssh the correct owner"

# cause root partition to be sized to 4GB so there's room left for a data partition
# note that the size is in 512-byte sectors
sudo sed -i -e 's/\(\s*TARGET_END=\).*/\18388608/' $rootfs/usr/lib/raspi-config/init_resize.sh

echo "Ready!"
