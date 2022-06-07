#! /bin/bash -e
# Initial Sensorgnome config: user password and "short name"
cd /opt/sensorgnome/web-portal
touch public/need_init # used by caddy to route

if egrep '^gnome:[^!x:][^:]{10,}' /etc/shadow; then
    echo "Password has been set"
    rm -f public/need_init
fi

# it's still the original password, start the "initial config" app and force the user to change it
[[ -f public/need_init ]] && /opt/sensorgnome/wifi-button/wifi-hotspot.sh on
echo "Starting initial config app"
node ./config.js
