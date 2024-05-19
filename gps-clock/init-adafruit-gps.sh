#! /usr/bin/bash -ex
#DTP=/proc/device-tree/hat/product
SGH=/dev/sensorgnome/hat
mkdir -p /dev/sensorgnome

# Note: the code here disables getty to free up access to the serial port, then symlinks
# /dev/ttyGPS to the gps's port, and finally restarts gpsd.
# The 'proper' way to add a port to GPSd is to run run gpsdctl@<port>.service and that's
# how USB-attached GPSes work. However, if gpsd is restarted then all the dynamically
# added devices are lost.

# Detect Adafruit GPS HAT. Its EEPROM causes /proc/device-tree/hat/product to be set
if [[ -f $SGH ]] && grep -q "Ultimate GPS HAT" $SGH; then
    echo "Adafruit GPS HAT detected, starting GPSd and enabling PPS input to chrony"
    dev=$(readlink /dev/serial0) # ttyAMA0 or ttyS0
    systemctl stop serial-getty@$dev.service
    ln -f -s /dev/serial0 /dev/sensorgnome/gps.port=0.pps=1.kind=hat.model=adafruit
    # Set speed to 9600 baud for prompt discovery
    stty -F /dev/serial0 raw 9600 min 0 time 100
    sleep 1
    echo -e '\r\n$PMTK605*31\r' >/dev/ttyGPS; # query GPS firmware version while we're at it
    # For diagnostic purposes, check that we can see the gps
    lines=$(timeout 4 cat /dev/serial0 || true)
    if [[ "$lines" == *\$GPRMC,* ]]; then
        echo "Got GPS stanzas at 9600 baud"
    else
        echo "No GPS stanzas at 9600 baud:"
        od -c <<<"$lines"
    fi
    # Tell GPSd to look at serial0
    #systemctl start --no-block gpsdctl@serial0.service
    ln -f -s /dev/serial0 /dev/ttyGPS
    systemctl restart --no-block gpsd.service
    # Enable GPIO 4 for PPS from the Adafruit GPS hat
    dtoverlay pps-gpio gpiopin=4
    # Enable PPS in chrony
    sed -i '/refclock PPS/s/^#//' /etc/chrony/chrony.conf
    #systemctl restart chrony.service # chrony should not start before this unit is done
    exit 0
else
    echo "No Adafruit GPS HAT detected, disabling PPS input to chrony"
    if grep -q '^refclock PPS' /etc/chrony/chrony.conf; then
        sed -i '/^refclock PPS/s/^/#/' /etc/chrony/chrony.conf
        #systemctl restart chrony.service
    fi
fi

# Detect Sensorstations with built-in GPS
# Comment this out / disable in order to see the SS TTY console for troubleshooting
if [[ $(cat /etc/sensorgnome/id) == *RPS* ]]; then
    echo "SensorStation detected, starting GPSd"
    # Stopping getty also opens up permissions on the serial port
    dev=$(readlink /dev/serial0) # ttyAMA0 or ttyS0
    systemctl stop serial-getty@$dev.service
    # Enable GPS power
    raspi-gpio set 28 op dh
    sleep 1 # time for GPS to start-up (do we need this?)
    # Set speed to 9600 baud for prompt discovery
    stty -F /dev/serial0 raw 9600
    # Tell GPSd to look at serial0
    #systemctl start --no-block gpsdctl@serial0.service
    ln -f -s /dev/serial0 /dev/ttyGPS
    systemctl restart --no-block gpsd.service
fi
