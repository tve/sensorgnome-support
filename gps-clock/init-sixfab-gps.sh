#! /usr/bin/bash -e
SGH=/dev/sensorgnome/hat
mkdir -p /dev/sensorgnome

# This script needs to be triggered by the USB detection of the Telit (or other) modem.
# The udev rules for this are in the sg-sixfab package.
# This script is run as pre-exec for sixfab-core service so it doesn't get run umpteen times
# as the various Telit devices are detected.
# As part of the sixfab core service it runs as user=sixfab, hence the sudos below

# Detect SixFab Base HAT with modem that has GPS. While this HAT has an EEPROM it may be used in
# in combination with a UPS HAT which also has an EEPROM and that causes the detection to be scrambled
# 'cause the rPi folks didn't anticipate the use of multiple stacked HATs...
# We do have a udev rule in the sg-sixfab package that creates the $SGH file, though...
if [[ -f $SGH ]] && grep -q "Sixfab Base HAT" $SGH; then
    echo "Sixfab Base HAT detected"
    ls -ls /dev/serial/by-id  # FIXME: this will initially fail, svc restarts, then succeeds
    ttygps=/dev/serial/by-id/*LE91*-if04-*
    ttyat=/dev/serial/by-id/*LE91*-if05-*
    sudo ln -f -s $ttygps /dev/sensorgnome/gps.port=0.pps=1.kind=hat.model=sixfab
    sudo ln -f -s $ttygps /dev/ttyGPS
    # This HAT does not have a PPS output :-(
    # power-up GPS
    atcom -v -p $ttyat --rts-cts --dsr-dtr 'AT$GPSP=1'
    # enable output on ttyUSB1 with GGA, GLL, GSA, GSV, and RMC sentences
    atcom -v -p $ttyat --rts-cts --dsr-dtr 'AT$GPSNMUN=2,1,1,1,1,1,0'
    # save settings
    atcom -v -p $ttyat --rts-cts --dsr-dtr 'AT$GPSSAV'
    exit 0
fi