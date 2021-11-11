#! /usr/bin/bash
#
# turn wifi hotspot on or off
#
# Usage: wifi_hotspot [on|off]

if [[ "$1" == "off" ]]; then
    echo "Disabling Wifi HotSpot"
    systemctl stop hostapd
    systemctl stop dnsmasq
else
    echo "Starting up Wifi HotSpot"
    rfkill unblock wlan # prob not necessary but harmless

    # Ensure we have a device for the AP
    if ! ip link show ap0 >/dev/null; then
        iw dev wlan0 interface add ap0 type __ap
        sleep 3 # seems to take time... hostapd fails if the dev isn't there
    fi

    # Ensure hostapd has the correct ssid/psk
    # FIXME: should also set the country code, but there may not be a NETWORK.TXT file
    SGID=$(cat /etc/sensorgnome_id)
    sed -i -e "s/^ssid=.*/ssid=SG-$SGID/" \
        -e "s/wpa_passphrase=.*/wpa_passphrase=SG-$SGID/" \
        /etc/hostapd/hostapd.conf
#       -e "s/country_code=.*/country_code=\"$WIFI_COUNTRY\"/" \

    systemctl start dnsmasq
    systemctl start hostapd
fi
