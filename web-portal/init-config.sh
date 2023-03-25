#! /bin/bash -e
# Initial Sensorgnome config: user password and "short name"
cd /opt/sensorgnome/web-portal
touch public/need_init # used by caddy to route

user=`getent passwd 1000 | cut -d: -f1`
if egrep -q "^${user}:[^!x:][^:]{10,}" /etc/shadow; then
    echo "Password has been set"
    rm -f public/need_init
fi

# start the landing page and initial config app
if [[ -f public/need_init ]]; then
    # initial config needed, ensure hotspot is on to do it
    echo "Initial SG config needed, turning hotspot on"
    /opt/sensorgnome/wifi-button/wifi-hotspot.sh on
else
    # initial config done, for now unconditionally turn on hot-spot, should have a setting somewhere
    echo "Initial SG config done, turning hotspot on anyway for now..."
    /opt/sensorgnome/wifi-button/wifi-hotspot.sh on
fi
echo "Starting web portal/landing page app"
node ./config.js
