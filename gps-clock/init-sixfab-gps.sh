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
    dsbi=/dev/serial/by-id
    if ! [[ -d $dsbi ]]; then echo "Modem not ready"; exit 1; fi
    ls -ls $dsbi  # FIXME: this will initially fail, svc restarts, then succeeds
    if [ -e $dsbi/*LE91*-if04-* ]; then
        ttygps=$dsbi/*LE91*-if04-*
        ttyat=$dsbi/*LE91*-if05-*
    elif [ -e $dsbi/Quectel_E[CG]25-*-if01-* ]; then
        ttygps=$dsbi/Quectel_E[CG]25-*-if01-*
        ttyat=$dsbi/Quectel_E[CG]25-*-if02-*
    else
        echo "Modem not recognized"
        if [ -e $dsbi/*-if04-* ]; then exit 0; else exit 1; fi # 0->dead, 1->retry
    fi
    sudo ln -f -s $ttygps /dev/sensorgnome/gps.port=0.pps=1.kind=hat.model=sixfab
    sudo ln -f -s $ttygps /dev/ttyGPS
    sudo gpsdctl add /dev/ttyGPS
    sudo systemctl restart gestures.service
    # This HAT does not have a PPS output :-(
    # power-up GPS
    atcom -v -p $ttyat --rts-cts --dsr-dtr 'AT$GPSP=1'
    # enable output on ttyUSB1 with GGA, GLL, GSA, GSV, and RMC sentences
    atcom -v -p $ttyat --rts-cts --dsr-dtr 'AT$GPSNMUN=2,1,1,1,1,1,0'
    # save settings
    atcom -v -p $ttyat --rts-cts --dsr-dtr 'AT$GPSSAV'
    exit 0
fi
