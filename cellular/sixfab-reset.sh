#! /bin/bash -x
# GPIO 26 control power to the modem: 0=ON, 1=OFF
# GPIO 13 controls DTR to the modem: pulse low to wake-up from sleep

cd /sys/class/gpio
[[ -d gpio26 ]] || echo 26 >export
echo out >gpio26/direction 
echo 1 >gpio26/value # power off
sleep 5
echo 0 >gpio26/value # power on
sleep 2

[[ -d gpio13 ]] || echo 13 >export
echo out >gpio13/direction
echo 0 >gpio13/value # DTR asserted
sleep 1
echo 1 >gpio13/value # DTR released
sleep 1
