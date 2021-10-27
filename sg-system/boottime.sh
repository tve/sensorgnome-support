#!/bin/bash
#
# boot-time tasks for Sensor Gnome (for debian 7.0 armhf)
#
# These must be run before network interfaces are brought up!
# This script is linked from /etc/rcS.d, before networking.

# ensure we have /dev/sensorgnome, whose existence is required
# for the master process to work.  It is automatically created
# when USB devices are attached, but otherwise would not exist,
# so we make sure to do that here.  Moreover, we make sure
# to create a usb subdirectory, so that even if every device
# is removed, the /dev/sensorgnome directory does not disappear,
# which would break hubman.js's Fs.watch() of it.

mkdir -p /dev/sensorgnome/usb

# The "Datasaver" in sensorgnome expects to write data to /media/SD_card and
# /media/diskNportM, so ensure /media/SD_card is a symlink to /data
[[ -e /media/SD_card ]] || ln -s /data /media/SD_card

# make sure serial number-hostname for local host is in /etc/hosts
sed -i /etc/hosts -e "/127.0.0.1[ \t]\+localhost/s/^.*$/127.0.0.1\tlocalhost `hostname`/"

# if a file called /boot/GESTURES.TXT exists, then disable WiFi at
# boot time.  This should have no effect on the Pi2, unless you plug
# in a WiFi dongle, in which case, who knows.

if [[ -f /boot/GESTURES.TXT ]]; then
    systemctl stop hostapd
    ifdown wlan0
# looks like there's no button so start hotspot by default
# unless there's no config file for it...
elif [[ -f /etc/hostapd/hostapd.conf ]]; then
    ifup wlan0
    systemctl start hostapd
else
    systemctl stop hostapd
fi

# - generate the sensorgnome unique system ID into /etc/sensorgnome_id
# This ID is associated with the CPU chip, thus if the hardware is swapped out due to a failure
# the station will get a new ID...

/home/pi/proj/sensorgnome/scripts/gen_id.sh

# - increment the persistent bootcount in /etc/bootcount

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

# - delete any empty unmounted directores named /media/disk_portX.Y
#   These might be leftover from previous boots with disks plugged
#   into different slots.  As a failsafe, if the directory isn't
#   empty, we don't delete (since we're using rmdir) - the folder
#   might contain real data.

for dir in /media/disk*port*; do
    if ( ! ( mount -l | grep -q " on $dir " ) ); then
        if [ "$(ls -A $dir 2> /dev/null)" == "" ]; then
            rmdir $dir
        fi
    fi
done

# - delete stale udhcpd leases file - else connection from a USB-connected
#   computer might fail since we only allow a single lease.

rm -f /var/lib/misc/udhcpd.leases

# force write to disk
sync

# maybe set the system clock from the RTC
/home/pi/proj/sensorgnome/scripts/maybe_get_clock_from_rtc.sh

# maybe do a software update
/home/pi/proj/sensorgnome/scripts/update_software.sh

# configure the Wifi network acording to user preferences in
/home/pi/proj/sensorgnome/scripts/getnetwork

# If this SG is not yet registered, then add an appropriate entry to
# the system crontab vi /etc/cron.d
# Successful registration will delete that file.

UNIQUE_KEY_FILE=/home/pi/.ssh/id_dsa

if [[ ! -f $UNIQUE_KEY_FILE ]]; then
    echo '* * *    *   *   root  /home/pi/proj/sensorgnome/scripts/register_sg' > /etc/cron.d/register_sg
fi
