#! /bin/bash -e

# Push ID into telegraf monitoring config
SGID=$(cat /etc/sensorgnome/id)
if grep -q 'SGID' /etc/default/telegraf; then
    sed -i "s/SGID=.*/SGID=SG-$SGID/" /etc/default/telegraf
else
    echo "SGID=SG-$SGID" >>/etc/default/telegraf
fi

if ! grep -q SGKEY /etc/default/telegraf; then
    key=$(dd if=/dev/urandom bs=100 count=1 2>/dev/null | md5sum | sed -e 's/ .*//')
    echo "SGKEY=$key" >>/etc/default/telegraf
fi
