#! /bin/bash
# Initial Sensorgnome config: user password and "short name"
cd /opt/sensorgnome/web-portal
touch public/need_init # used by caddy to route

user=`getent passwd 1000 | cut -d: -f1`
if egrep -q "^${user}:[^!x:][^:]{10,}" /etc/shadow; then
    echo "Unix password has been set"
    if [[ $(../wifi-button/wifi-hotspot.sh pwinfo) == "set" ]]; then
        echo "Hotspot password has been set"
        rm -f public/need_init
    else
        echo "Hotspot password has not been set"
    fi
fi

# start the landing page and initial config app
if [[ -f public/need_init ]]; then
    # initial config needed, ensure hotspot is on to do it
    echo "Initial SG config needed, turning hotspot on"
    /opt/sensorgnome/wifi-button/wifi-hotspot.sh on & # don't die if this fails...
else
    # initial config done, for now unconditionally turn on hot-spot, should have a setting somewhere
    echo "Initial SG config done, turning hotspot on anyway for now..."
    /opt/sensorgnome/wifi-button/wifi-hotspot.sh on & # don't die if this fails...
fi
echo "Starting web portal/landing page app"
node ./config.js
