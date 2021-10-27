#! /bin/bash
#
# boot-time tasks for Sensor Gnome (for debian 7.0 armhf
# These must be run before network interfaces are brought up!

# Generate the sensorgnome unique system ID into /etc/sensorgnome_id
# This ID is associated with the CPU chip, thus if the hardware is swapped out due to a failure
# the station will get a new ID...
./gen_id.sh

# Make sure serial number-hostname for local host is in /etc/hosts
sed -i /etc/hosts -e "/127.0.0.1[ \t]\+localhost/s/^.*$/127.0.0.1\tlocalhost `hostname`/"

# Increment the persistent bootcount in /etc/bootcount
BOOT_COUNT_FILE="/etc/bootcount"
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

# FIXME: figure out how this is supposed to work
# maybe do a software update
#/home/pi/proj/sensorgnome/scripts/update_software.sh

# FIXME: move to ssh-comms subsystem
# FIXME: needs to be tied to SG_ID, need new reg is moving to a different SG hardware
# If this SG is not yet registered, then add an appropriate entry to
# the system crontab vi /etc/cron.d
# Successful registration will delete that file.
UNIQUE_KEY_FILE=/home/pi/.ssh/id_dsa
if [[ ! -f $UNIQUE_KEY_FILE ]]; then
    echo '* * *    *   *   root  /home/pi/proj/sensorgnome/scripts/register_sg' > /etc/cron.d/register_sg
fi
