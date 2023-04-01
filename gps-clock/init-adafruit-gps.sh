#! /usr/bin/bash -e
#DTP=/proc/device-tree/hat/product
SGH=/dev/sensorgnome/hat
mkdir -p /dev/sensorgnome

# Detect Adafruit GPS HAT. Its EEPROM causes /proc/device-tree/hat/product to be set
if [[ -f $SGH ]] && grep -q "Ultimate GPS HAT" $SGH; then
    echo "Adafruit GPS HAT detected, enabling PPS input to chrony"
    /usr/bin/systemctl stop serial-getty@ttyS0.service
    ln -f -s /dev/serial0 /dev/sensorgnome/gps.port=0.pps=1.kind=hat.model=adafruit
    # Enable GPIO 4 for PPS from the Adafruit GPS hat
    dtoverlay pps-gpio gpiopin=4
    # Enable PPS in chrony
    sed -i '/refclock PPS/s/^#//' /etc/chrony/chrony.conf
    systemctl restart chrony.service
    exit 0
else
    echo "No Adafruit GPS HAT detected, disabling PPS input to chrony"
    if grep -q '^refclock PPS' /etc/chrony/chrony.conf; then
        sed -i '/^refclock PPS/s/^/#/' /etc/chrony/chrony.conf
        systemctl restart chrony.service
    fi
fi

# Detect Sensorstations with built-in GPS
if egrep -q 'Module 3 Plus' /proc/device-tree/model; then
    if [[ "$(lsusb | grep -c 0424:2514)" == 4 ]]; then
      # Sensorstation V1/V2
      ln -s /dev/ttyACM0 /dev/ttyGPS
    else
      # Sensorstation V3
      ln -s /dev/ttyACM0 /dev/ttyGPS
    fi
fi
