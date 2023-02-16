#! /bin/bash -e

# Push ID into telegraf monitoring config
SGID=$(cat /etc/sensorgnome/id)
if grep -q 'SGID' /etc/default/telegraf; then
    sed -i "s/SGID=.*/SGID=$SGID/" /etc/default/telegraf
else
    echo "SGID=$SGID" >>/etc/default/telegraf
fi

if ! grep -q SGKEY /etc/default/telegraf; then
    echo "SGKEY=$(cat /etc/sensorgnome/key)" >>/etc/default/telegraf
fi

if ! grep -q INTERVAL /etc/default/telegraf; then
    echo "INTERVAL=10m" >>/etc/default/telegraf
fi
