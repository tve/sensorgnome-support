#! /bin/bash
#
# boot-time tasks for Sensor Gnome (for debian 7.0 armhf)
# These must be run before network interfaces are brought up!

# Generate the sensorgnome unique system ID into /etc/sensorgnome/id
# This ID is associated with the CPU chip, thus if the hardware is swapped out due to a failure
# the station will get a new ID...
./gen_id.sh

# Make sure serial number-hostname for local host is in /etc/hosts
sed -i /etc/hosts -e "/127.0.0.1[ \t]\+localhost/s/^.*$/127.0.0.1\tlocalhost `hostname`/"

# Increment the persistent bootcount in /etc/bootcount
BOOT_COUNT_FILE="/etc/sensorgnome/bootcount"
if [[ -f $BOOT_COUNT_FILE ]]; then
    COUNT=`cat $BOOT_COUNT_FILE`;
    if [[ "$COUNT" == "" ]]; then
        COUNT=0;
    fi
    echo $(( 1 + $COUNT )) > $BOOT_COUNT_FILE
else
    echo 1 > $BOOT_COUNT_FILE
fi
echo "The boot count is $(cat $BOOT_COUNT_FILE)"
sync

# Create /data partition if we don't have one yet
./create_data_part.sh

# The "Datasaver" in sensorgnome expects to write data to /media/SD_card and
# /media/diskNportM, so ensure /media/SD_card is a symlink to /data
[[ -e /media/SD_card ]] || ln -s /data /media/SD_card

# mount and move specific files from /boot into /etc/sensorgnome, the reason for this is that
# boot is a fat32 filesystem where the user can edit some config files before first boot
echo "Moving data from /boot to /etc/sensorngome"
shopt -s nullglob
if [[ -n $(echo /boot/*tag*.sqlite) ]]; then
    mv /boot/*tag*.sqlite /etc/sensorgnome/SG_tag_database.sqlite
fi
if [[ -f /boot/usb-port-map.txt ]]; then
    mv /boot/usb-port-map.txt /etc/sensorgnome/
fi
if [[ -n $(echo /boot/*.pub) ]]; then
    username=`getent passwd 1000 | cut -d: -f1`
    mkdir -p "/home/${username}/.ssh"
    cat /boot/*.pub >>"/home/${username}/.ssh/authorized_keys"
    chown -R "${username}" "/home/${username}/.ssh"
    chmod 644 /home/${username}/.ssh/*
    rm /boot/*.pub
fi

# Detect any HAT with the ability to explicitly override for HATs that don't detect properly,
# for example when stacking two HATs, which is something the rpi cannot detect.
mkdir -p /dev/sensorgnome
if [[ -f /proc/device-tree/hat/product ]]; then
    cp /proc/device-tree/hat/product /dev/sensorgnome/hat
fi
if [[ -f /etc/sensorgnome/force-hat ]]; then
    cp /etc/sensorgnome/force-hat /dev/sensorgnome/hat
fi

# ensure we're running in UTC
rm -f /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
