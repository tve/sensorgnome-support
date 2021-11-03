#!/bin/bash

# Ensure we have /dev/sensorgnome, whose existence is required
# for the master process to work.  It is automatically created
# when USB devices are attached, but otherwise would not exist,
# so we make sure to do that here.  Moreover, we make sure
# to create a usb subdirectory, so that even if every device
# is removed, the /dev/sensorgnome directory does not disappear,
# which would break hubman.js's Fs.watch() of it.
mkdir -p /dev/sensorgnome/usb

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

