#!/bin/bash

# Ensure we have /dev/sensorgnome, whose existence is required
# for the master process to work.  It is automatically created
# when USB devices are attached, but otherwise would not exist,
# so we make sure to do that here.  Moreover, we make sure
# to create a usb subdirectory, so that even if every device
# is removed, the /dev/sensorgnome directory does not disappear,
# which would break hubman.js's Fs.watch() of it.
mkdir -p /dev/sensorgnome/usb

# if there is no port mapping file pick the most appropriate one based on the
# rPi model.
cd /opt/sensorgnome/udev-usb
if ! [[ -f /etc/sensorgnome/usb-port-map.txt ]]; then
  # Raspberry Pi 4 Model B Rev 1.4
  MODEL=$(sed -E -e 's/[^0-9]*([0-9]+)\s*Model\s*(\S+)\s.*/\1\2/' /proc/device-tree/model)
  if [[ -f usb-port-map-$MODEL.txt ]]; then
    echo "Model is $MODEL, selecting usb-port-map-$MODEL.txt"
    cp usb-port-map-$MODEL.txt /etc/sensorgnome/usb-port-map.txt
  else
    echo "Model is $MODEL, selecting usb-port-map-generic.txt"
    cp usb-port-map-generic.txt /etc/sensorgnome/usb-port-map.txt
  fi
fi

# - delete any empty unmounted directories named /media/disk_portX.Y
#   These might be leftover from previous boots with disks plugged
#   into different slots.  As a failsafe, if the directory isn't
#   empty, we don't delete (since we're using rmdir) - the folder
#   might contain real data.
shopt -s nullglob
for dir in /media/disk*port*; do
    if ( ! ( mount -l | grep -q " on $dir " ) ); then
        if [ "$(ls -A $dir 2> /dev/null)" == "" ]; then
            rmdir $dir
        fi
    fi
done
