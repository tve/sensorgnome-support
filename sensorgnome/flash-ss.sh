#! /bin/bash -e
# Flash a SensorStation (Compute Module) attached via USB

if [[ -z $1 ]]; then echo "usage: $0 <url>"; exit 1; fi

url=$1
zip=$(basename $1)
img=$(basename $1 zip)img
cd /data
if ! [[ -f $zip ]]; then
    echo Downloading $url
    wget -nv -O $zip $url
fi
echo Unmounting
umount /run/media/$USER/* 2>/dev/null || true

if ! [[ -f /usr/bin/rpiboot ]]; then
    echo "rpiboot not found, installing"
    sudo apt-get update
    sudo apt-get install -y rpiboot
fi

dev=$(lsblk -d -o NAME,VENDOR,SIZE | grep -E 'RPi-MSD.*[2356][0-9]\.[0-9]G' | cut -d" " -f1)
if [[ -z $dev ]]; then
    echo "No device found, running rpiboot"
    sudo rpiboot
    sleep 5
    dev=$(lsblk -d -o NAME,VENDOR,SIZE | grep -E 'RPi-MSD.*[2356][0-9]\.[0-9]G' | cut -d" " -f1)
    if [[ -z $dev ]]; then echo "No device found."; exit 1; fi
fi
dev=/dev/$dev

echo "Flashing $dev: $(lsblk -dn -o VENDOR,MODEL,SIZE $dev)"
echo "Takes 15-20 minutes!"
sleep 5
7z e -so $zip $img | sudo dd of=$dev bs=10M
