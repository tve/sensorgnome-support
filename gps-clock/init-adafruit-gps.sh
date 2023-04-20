#! /usr/bin/bash -e
#DTP=/proc/device-tree/hat/product
SGH=/dev/sensorgnome/hat
mkdir -p /dev/sensorgnome

# Detect Adafruit GPS HAT. Its EEPROM causes /proc/device-tree/hat/product to be set
if [[ -f $SGH ]] && grep -q "Ultimate GPS HAT" $SGH; then
    echo "Adafruit GPS HAT detected, starting GPSd and enabling PPS input to chrony"
    dev=$(readlink /dev/serial0) # ttyAMA0 or ttyS0
    systemctl stop serial-getty@$dev.service
    ln -f -s /dev/serial0 /dev/sensorgnome/gps.port=0.pps=1.kind=hat.model=adafruit
    # Set speed to 9600 baud for prompt discovery
    stty -F /dev/serial0 speed 9600
    # Tell GPSd to look at serial0
    systemctl start --no-block gpsdctl@serial0.service
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
if [[ $(cat /etc/sensorgnome/id) == *RPS* ]]; then
    echo "SensorStation detected, starting GPSd"
    # Stopping getty also opens up permissions on the serial port
    dev=$(readlink /dev/serial0) # ttyAMA0 or ttyS0
    systemctl stop serial-getty@$dev.service
    # Enable GPS power
    raspi-gpio set 28 op dh
    sleep 1 # time for GPS to start-up (do we need this?)
    # Set speed to 9600 baud for prompt discovery
    stty -F /dev/serial0 speed 9600
    # Tell GPSd to look at serial0
    systemctl start --no-block gpsdctl@serial0.service
fi
