#! /usr/bin/bash -e
# export gpio pins for use with either the adafruit pushbutton LED switch or the button/LED on
# the sixfab cellular hat
#DTP=/proc/device-tree/hat/product
SGH=/dev/sensorgnome/hat

LED_GPIO=

# Detect Adafruit GPS HAT. It's EEPROM causes /proc/device-tree/hat/product to be set
if [[ -f $SGH ]] && grep -q "Ultimate GPS HAT" $SGH; then
    echo "Adafruit GPS HAT detected"
    dtoverlay gpio_pull
    LED_GPIO=17
    SW_GPIO=18
fi

# Detect SixFab Base HAT with modem that has GPS. While this HAT has an EEPROM it may be used in
# in combination with a UPS HAT which also has an EEPROM and that causes the detection to be scrambled
# 'cause the rPi folks didn't anticipate the use of multiple stacked HATs...
# We do have a udev rule in the sg-sixfab package that creates the $SGH file, though...
if [[ -f $SGH ]] && grep -q "Sixfab Base HAT" $SGH; then
    echo "Sixfab Base HAT detected"
    LED_GPIO=27
    SW_GPIO=22
fi

# Detect Ad-hoc button HAT.
if [[ -f $SGH ]] && grep -q "button-17-18" $SGH; then
    echo "Ad-hoc button HAT detected"
    dtoverlay gpio_pull
    LED_GPIO=17
    SW_GPIO=18
fi

if [[ -z "$LED_GPIO" ]]; then
    echo "No LED/SW for gestures"
    exit 1
fi

echo "Enabling GPIO $LED_GPIO for LED and GPIO $SW_GPIO for button"

dir=$PWD
cd /sys/class/gpio
[[ -e gpio$LED_GPIO ]] || echo $LED_GPIO > export
echo out > gpio$LED_GPIO/direction
echo 0 > gpio$LED_GPIO/value

[[ -e gpio$SW_GPIO ]] || echo $SW_GPIO > export
echo 1 > gpio$SW_GPIO/active_low

cd $dir
cat <<EOF >$1
GEST_LED_GPIO=$LED_GPIO
GEST_SW_GPIO=$SW_GPIO
EOF
