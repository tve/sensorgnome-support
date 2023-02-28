#! /bin/bash -ex
# Install the sixfab core manager. The steps performed here are gleaned from
# https://install.connect.sixfab.com, which is a fine shell script but makes it pretty non-obvious
# what is being modified...

# create sixfab user with appropriate permissions, etc.
if ! egrep -q sixfab /etc/passwd; then
    adduser --disabled-password --gecos "" sixfab
    usermod -aG spi sixfab
    usermod -aG i2c sixfab
    usermod -aG gpio sixfab
    usermod -aG sudo sixfab
    usermod -aG dialout sixfab
    usermod -aG users sixfab
    usermod -aG plugdev sixfab
    echo "sixfab ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sixfab_core

    # usb permissions for plugdev
    PERMISSIONS_TO_ADD="SUBSYSTEM==\"usb\", ENV{DEVTYPE}==\"usb_device\", MODE=\"0664\", GROUP=\"plugdev\""
    PLUGDEV_RULES_PATH=/etc/udev/rules.d/plugdev_usb.rules
    if [ ! -f $PLUGDEV_RULES_PATH ]; then
        echo $PERMISSIONS_TO_ADD >$PLUGDEV_RULES_PATH
        udevadm control --reload
        udevadm trigger
    fi
fi

chown -R sixfab /opt/sixfab
mkdir -p /var/log/sixfab
chown -R sixfab /var/log/sixfab

# python prereqs are installed in the image:
#pip3 install --no-cache-dir -U atcom (also pyyaml and pyusb)
#sudo -u sixfab pip3 install -r core_manager/requirements.txt --no-cache-dir

# prevent installation of the sixfab software from the sixfab site 'cause it ends
# up in conflicts
if [[ -d /opt/sixfab/core ]]; then
    mv -f /opt/sixfab/core /opt/sixfab/core.disabled
fi
echo "DO NOT INSTALL THE SIXFAB SOFTWARE FROM THEIR SITE" > /opt/sixfab/core
echo "https://github.com/tve/sensorgnome-build/blob/pimod/SIXFAB.md" >> /opt/sixfab/core
