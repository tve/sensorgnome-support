#! /usr/bin/bash -e
# export gpio pins for use with the adafruit pushbutton LED switch

. $1
echo "Enabling GPIO $GEST_LED_GPIO for LED and GPIO $GEST_SW_GPIO for button"

cd /sys/class/gpio
[[ -e gpio$GEST_LED_GPIO ]] || echo $GEST_LED_GPIO > export
echo out > gpio$GEST_LED_GPIO/direction
echo 0 > gpio$GEST_LED_GPIO/value

[[ -e gpio$GEST_SW_GPIO ]] || echo $GEST_SW_GPIO > export
echo 1 > gpio$GEST_SW_GPIO/active_low
