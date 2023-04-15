#! /bin/bash
# display state using system LEDs (e.g. red and green LED on rPi 4B)
# usage: sysled.sh <hostspot_state> <internet_state>
# where each state is "off"/"on"

# The rPi boards all have different LED arrangements...
# rPi 4B: led0=green led1=red; both can be controlled
# rPi 3B+: led0=green led1=red; both can be controlled
# rPi 3B: led0=green led1=red; both can be controlled
# rPi Z2W: ACT=green; there is no red "power" LED
# SSV1: led0=green; there is no controllable "power" LED

if [[ $# != 2 ]]; then
    echo "Usage: sysled.sh <hotspot_state> <internet_state>"
    echo "state should be on/off"
    exit 1
fi
hotspot=$1
internet=$2

# patterns
blink1="1 1000 0 1000"
blink2="1 200 0 200 1 200 0 1000"
blink3="1 200 0 200 1 200 0 200 1 200 0 1000"

# figure out the LED device to use
dev=/sys/class/leds/led0
[[ -e /sys/class/leds/ACT ]] && dev=/sys/class/leds/ACT

# ensure the pattern driver is loaded and selected
if [[ ! -e $dev/pattern ]]; then
    modprobe ledtrig-pattern
    echo pattern > $dev/trigger
fi

# set the pattern
if [[ $internet == on ]]; then
    echo $blink3 > $dev/pattern
elif [[ $hotspot == on ]]; then
    echo $blink2 > $dev/pattern
else
    echo $blink1 > $dev/pattern
fi
