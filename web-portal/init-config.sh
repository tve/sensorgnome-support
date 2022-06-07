#! /bin/bash -e
# Initial Sensorgnome config: user password and "short name"
cd /opt/sensorgnome/web-portal
touch public/need_init # used by caddy to route

if ! [[ -f /etc/pi.pass ]]; then
    echo "No saved password to compare, must have changed it already"
    rm -f public/need_init
else
    # check whether password has been changed
    pw_etc=$(egrep '^pi:' /etc/shadow)
    pw_save=$(cat /etc/pi.pass)
    if [[ "$pw_etc" != "$pw_save" ]]; then
        # changed, done with this...
        rm /etc/pi.pass
        echo "Password changed, removed pi.pass"
        rm -f public/need_init
    fi
fi

# it's still the original password, start the "initial config" app and force the user to change it
[[ -f public/need_init ]] && /opt/sensorgnome/wifi-button/wifi-hotspot.sh on
echo "Starting initial config app"
node ./config.js
