#! /usr/bin/bash
#
# turn wifi hotspot on or off
#
# Usage: wifi_hotspot [on|off]

if [[ "$1" == "off" ]]; then
    echo "Disabling Wifi HotSpot"
    systemctl stop dnsmasq
    systemctl stop hostapd
    iptables -t nat -D PREROUTING -s 192.168.7.0/24 -p tcp --dport 80 -j DNAT --to-destination 192.168.7.2:81
else
    echo "Starting up Wifi HotSpot"
    rfkill unblock wlan # prob not necessary but harmless

    # Ensure we have a device for the AP
    if ! ip link show ap0 2>/dev/null; then
        iw dev wlan0 interface add ap0 type __ap
        sleep 3 # seems to take time... hostapd fails if the dev isn't there
    fi

    # Ensure resolvconf doesn't pick up on the dnsmasq we're about to start
    if ! egrep -q lo.dnsmasq /etc/resolvconf.conf; then
        echo "# prevent captive portal dnsmasq from becoming a resolver" >> /etc/resolvconf.conf
        echo "deny_interfaces=lo.dnsmasq" >> /etc/resolvconf.conf
        resolvconf -u
    fi

    # Ensure hostapd has the correct ssid/psk
    # FIXME: should also set the country code, but there may not be a NETWORK.TXT file
    # But the "global" country code 00 is probably just fine
    SGID=$(cat /etc/sensorgnome_id)
    sed -i -e "s/^ssid=.*/ssid=SG-$SGID/" \
        /etc/hostapd/hostapd.conf
#       -e "s/wpa_passphrase=.*/wpa_passphrase=SG-$SGID/" \
#       -e "s/country_code=.*/country_code=\"$WIFI_COUNTRY\"/" \

    systemctl start hostapd
    systemctl start dnsmasq

    # Set-up captive portal
    iptables -t nat -A PREROUTING -s 192.168.7.0/24 -p tcp --dport 80 -j DNAT --to-destination 192.168.7.2:81
fi
