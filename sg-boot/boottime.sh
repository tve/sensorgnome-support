#! /bin/bash
#
# boot-time tasks for Sensor Gnome (for debian 7.0 armhf
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
[[ -n $(echo /boot/*tag*.sqlite) ]] && cp /boot/*tag*.sqlite /etc/sensorgnome/SG_tag_database.sqlite
if [[ -n $(echo /boot/*.pub) ]]; then
    mkdir -p /home/gnome/.ssh
    cat /boot/*.pub >>/home/gnome/.ssh/authorized_keys
    chown -R gnome /home/gnome/.ssh
    chmod 644 /home/gnome/.ssh/*
fi
