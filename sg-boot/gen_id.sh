#! /bin/bash
# Generate the sensorgnome unique system ID into /etc/sensorgnome/id
# This ID is associated with the CPU chip, thus if the hardware is swapped out due to a failure
# the station will get a new ID...
# Currently this only works for rpi, will need to be enhanced for BBB

RPI_ID=$(grep Serial /proc/cpuinfo | /bin/sed -re 's/^.*(.{4})(.{4})/\1====\2/'  | tr [:lower:] [:upper:])
# Distinguish between "regular RPI" and "RPI Zero"
CLASS=RPI
egrep -qi zero /proc/device-tree/model && CLASS=RPZ
# Model digit
MODEL=$(sed -e 's/[^0-9]*\([0-9]\).*/\1/' /proc/device-tree/model) # first digit, e.g. rpi 400 -> 4
RPI_ID=${RPI_ID/====/$CLASS$MODEL}
echo $RPI_ID > /etc/sensorgnome/id

HOSTNAME="SG-${RPI_ID}"
echo $HOSTNAME > /etc/hostname

echo "Setting hostname to '$HOSTNAME'"
hostname "$HOSTNAME"

# Note: originally the model was derived from /proc/cpuinfo's REVISION field. Up-to-date info
# on mapping that can be found at https://www.raspberrypi-spy.co.uk/2012/09/checking-your-raspberry-pi-board-version/
# in case the method needs to be reverted.
