#!/bin/bash
# Usage: program-radio.sh <channel> <hex_file> <op>
# Channel 1..5, Op: v=verify, w=program(default)

if [[ $(cat /etc/sensorgnome/id) == *RPS[12]* ]]; then
	# V3 radio map
	echo 'v3 radio map'
	CHAN=(
        '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.2.2:1.0'
	    '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.2.3:1.0'
	    '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.2.4:1.0'
	    '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.2.5:1.0'
	    '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.2.6:1.0'
    )
else
	# V2 radio map
	echo 'v1/v2 radio map'
	CHAN=(
        '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.2.2:1.0'
	    '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.3.1:1.0'
	    '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.3.2:1.0'
	    '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.3.3:1.0'
	    '/dev/serial/by-path/platform-3f980000.usb-usb-0:1.3.4:1.0'
    )
fi

# radio reset pins are the same for v1, v2 and v3
RESET=(12 34 35 36 37)

CHANNEL=${CHAN[$1-1]}
PIN=${RESET[$1-1]}
if [ "$CHANNEL" == "" ]; then
    echo "Invalid channel number $1"
    exit -1
fi

if [ "$2" == "" ]; then
	echo "Expected radio fw file as second input arg"
    exit -3
fi
if ! test -f "$2"; then
    echo "Radio FW File $2 does not exist"
    exit -2
fi
FW_FILE=$2

echo "Channel $CHANNEL, Reset pin $PIN, FW file $FW_FILE"
raspi-gpio set $PIN op dl
sleep 0.2
raspi-gpio set $PIN op dh
sleep 0.2
raspi-gpio set $PIN ip
sleep 1

OP=${3:-w}

avrdude -P $CHANNEL -c avr109 -patmega32u4  -b 57600 -D -v -Uflash:$OP:$FW_FILE:i
