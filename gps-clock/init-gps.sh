#! /usr/bin/bash -e
DTP=/proc/device-tree/hat/product
SGH=/dev/sensorgnome/hat
mkdir -p /dev/sensorgnome

# Detect Adafruit GPS HAT. Its EEPROM causes /proc/device-tree/hat/product to be set
if [[ -f $DTP ]] && grep -q "Ultimate GPS HAT" $DTP; then
    echo "Adafruit GPS HAT detected"
    /usr/bin/systemctl stop serial-getty@ttyS0.service
    ln -f -s /dev/serial0 /dev/sensorgnome/gps.port=0.pps=1.kind=hat.model=adafruit
    # Enable GPIO 4 for PPS from the Adafruit GPS hat
    dtoverlay pps-gpio gpiopin=4
    # Enable PPS in chrony
    sed -i '/refclock PPS/s/^#//' /etc/chrony/chrony.conf
    systemctl restart chrony.service
    exit 0
fi

# Detect SixFab Base HAT with modem that has GPS. While this HAT has an EEPROM it may be used in
# in combination with a UPS HAT which also has an EEPROM and that causes the detection to be scrambled
# 'cause the rPi folks didn't anticipate the use of multiple stacked HATs...
# We do have a udev rule in the sg-sixfab package that creates the $SGH file, though...
if [[ -f $SGH ]] && grep -q "Sixfab Base HAT" $SGH; then
    echo "Sixfab Base HAT detected"
    ln -f -s /dev/ttyUSB2 /dev/sensorgnome/gps.port=0.pps=1.kind=hat.model=sixfab
    # This HAT does not have a PPS output :-(
    # power-up GPS
    atcom -v -p /dev/ttyUSB3 --rts-cts --dsr-dtr 'AT$GPSP=1'
    # enable output on ttyUSB1 with GGA, GLL, GSA, GSV, and RMC sentences
    atcom -v -p /dev/ttyUSB3 --rts-cts --dsr-dtr 'AT$GPSNMUN=2,1,1,1,1,1,0'
    # save settings
    atcom -v -p /dev/ttyUSB3 --rts-cts --dsr-dtr 'AT$GPSSAV'
    exit 0
fi

echo "No GPS HAT detected"
