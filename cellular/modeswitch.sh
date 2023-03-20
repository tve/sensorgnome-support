#! /bin/bash
# Script to run an AT command on a modem addressed by USB verdor_id:product_id
# Used to switch USB composition on a modem
# Usage: modeswitch.sh vendor_id:product_id device_number command
# The device number is a parameter to "tail" and can be +n or -n
# Ex: modeswitch.sh 1bc7:1201 -3 'AT#USBCFG=4'

# return the devices that correspond to a given VID:PID
# from https://unix.stackexchange.com/a/668691/89116
vidpid_to_devs(){
  find $(grep -l "PRODUCT=$(printf "%x/%x" "0x${1%:*}" "0x${1#*:}")"  /sys/bus/usb/devices/[0-9]*:*/uevent |
         sed 's,uevent$,,') \
       /dev/null -name dev -o -name dev_id |
  sed 's,[^/]*$,uevent,' |
  xargs sed -n -e s,DEVNAME=,/dev/,p -e s,INTERFACE=,,p
}

# Figure out the device to use
devs=$(vidpid_to_devs $1)
echo Devices: $devs
dev=$(tail -n $2 <<<"$devs" | head -1)

# Send the AT command
echo "Sending $3 to $dev"
res=$(echo "$3" | socat -T 5 - ${dev},crnl)
echo "$res" | od -c
