#! /bin/bash
# -Generate the sensorgnome unique system ID into /etc/sensorgnome_id
# This ID is associated with the CPU chip, thus if the hardware is swapped out due to a failure
# the station will get a new ID...
# Currently this only works for rpi, will need to be enhanced for BBB

RPI_ID=`cat /proc/cpuinfo | /bin/grep Serial | /bin/sed -e 's/.*: //; s/^........//;s/^\(....\)/\1====/'  | tr [:lower:] [:upper:]`
MODEL=RPI`sed -e 's/[^0-9]*\([0-9]\).*/\1/' /proc/device-tree/model` # first digit, e.g. rpi 400 -> 4
RPI_ID=${RPI_ID/====/$MODEL}
echo $RPI_ID > /etc/sensorgnome_id

HOSTNAME="SG-${RPI_ID}"
echo $HOSTNAME > /etc/hostname

echo "Setting hostname to '$HOSTNAME'"
hostname "$HOSTNAME"

# Note: originally the model was derived from /proc/cpuinfo's REVISION field. Up-to-date info
# on mapping that can be found at https://www.raspberrypi-spy.co.uk/2012/09/checking-your-raspberry-pi-board-version/
# in case the method needs to be reverted.
