#! /bin/bash
# Generate the sensorgnome unique system ID into /etc/sensorgnome/id
# This ID is associated with the CPU chip, thus if the hardware is swapped out due to a failure
# the station will get a new ID...
# Currently this only works for rpi

RPI_ID=$(grep Serial /proc/cpuinfo | /bin/sed -re 's/^.*(.{4})(.{4})/\1====\2/'  | tr [:lower:] [:upper:])

# Treat Compute Modules specially: they belong to a board that presumably is different
# from a std RPi and may have special hardware that cannot be auto-detected
if egrep -q 'Module 3 Plus' /proc/device-tree/model; then
    # Detect Sensorstations
    if [[ "$(lsusb | grep -c 0424:2514)" == 4 ]]; then
      # Sensorstation V1/V2
      MODEL=RPS1
    else
      # Sensorstation V3
      MODEL=RPS3
    fi
else
    # RPi board. distinguish between "regular RPI" and "RPI Zero"
    CLASS=RPI
    egrep -qi zero /proc/device-tree/model && CLASS=RPZ
    # Model digit
    MODEL=$(sed -e 's/[^0-9]*\([0-9]\).*/\1/' /proc/device-tree/model) # first digit, e.g. rpi 400 -> 4
fi

RPI_ID=SG-${RPI_ID/====/$CLASS$MODEL}
echo $RPI_ID > /etc/sensorgnome/id

echo $RPI_ID > /etc/hostname

echo "Setting hostname to '$RPI_ID'"
hostname "$RPI_ID"

# Generate a random key in the form of an MD5 hash. This identifies the SD card and remains the
# the same if the card is moved to another rPi.
if ! [[ -f /etc/sensorgnome/key ]]; then
    key=$(dd if=/dev/urandom bs=100 count=1 2>/dev/null | md5sum | sed -e 's/ .*//')
    echo "$key" >/etc/sensorgnome/key
fi

# Note: originally the model was derived from /proc/cpuinfo's REVISION field. Up-to-date info
# on mapping that can be found at https://www.raspberrypi-spy.co.uk/2012/09/checking-your-raspberry-pi-board-version/
# in case the method needs to be reverted.
