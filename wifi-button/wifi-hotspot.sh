#! /usr/bin/bash
#
# turn wifi hotspot on or off
#
# Usage: wifi_hotspot [on|off]

# Iptables rule for traffic on hotspot destined for us
ipt_self="PREROUTING -s 192.168.7.0/24 -d 192.168.7.2 -p tcp --dport 80 -j DNAT --to-destination 192.168.7.2:81"
# Iptables rule for traffic on hotspot destined for routing, redirect to us
ipt_route="PREROUTING -s 192.168.7.0/24 ! -d 192.168.7.2 -p tcp --dport 80 -j DNAT --to-destination 192.168.7.2:82"
# Iptables rule for traffic on hotspot destined for routing, redirect to closed port (conn reset)
ipt_reset="PREROUTING -s 192.168.7.0/24 ! -d 192.168.7.2 -p tcp --dport 80 -j DNAT --to-destination 192.168.7.2:83"

if [[ "$1" == "off" ]]; then
    echo "Disabling Wifi HotSpot"
    systemctl stop dnsmasq
    systemctl stop hostapd
    iptables -t nat -D $ipt_reset
    iptables -t nat -D $ipt_route
    iptables -t nat -D $ipt_self
elif [[ "$1" == "capon" ]]; then
    # capon doesn't turn the interface on, it just configures iptables
    if ! iptables -t nat -n -L PREROUTING | egrep -q '192.168.7.2:82'; then
        echo "Turning captive portal on"
        iptables -t nat -D $ipt_reset
        iptables -t nat -A $ipt_route
    else
        echo "Captive portal already on"
    fi
elif [[ "$1" == "capoff" ]]; then
    # capoff doesn't turn the interface off, it just configures iptables
    if ! iptables -t nat -n -L PREROUTING | egrep -q '192.168.7.2:83'; then
        echo "Turning captive portal off"
        iptables -t nat -D $ipt_route
        iptables -t nat -A $ipt_reset
    else
        echo "Captive portal already off"
    fi
elif [[ "$1" == "capinfo" ]]; then
    if iptables -t nat -n -L PREROUTING | egrep -q '192.168.7.2:82'; then
        echo "on"
    else
        echo "off"
    fi
elif [[ "$1" == "pwinfo" ]]; then
    c=/etc/hostapd/hostapd.conf
    if grep -E -q '^wpa=2$' $c && egrep -E -q '^wpa_psk=[0-9a-f]{16}' $c; then
        echo "set"
    else
        echo "open"
    fi
elif [[ "$1" == "mode" ]]; then
    if [[ "$2" == "WPA-PSK" ]] || [[ "$2" == "SAE" ]]; then
        echo "Setting mode to $2"
        sed -i -r -e "s/^wpa_(passphrase|psk)=.*/wpa_psk=$3/" \
            -e "s/^wpa=.*/wpa=2/" \
            -e "/^ssid=/s/-init//" \
            /etc/hostapd/hostapd.conf
    #elif [[ "$2" == "OWE" ]]; then
    #    echo "Setting mode to $2"
    #    sed -i "s/^wpa_passphrase=.*/wpa_passphrase=xxx/" /etc/hostapd/hostapd.conf
    else
        echo "Unknown mode $2"
        exit 1
    fi
    sed -i -e "s/^wpa_key_mgmt=.*/wpa_key_mgmt=$2/" /etc/hostapd/hostapd.conf
    systemctl restart hostapd
elif iw dev | grep -q ap0; then
    # Ensure hostapd has the correct ssid/psk
    # Use different SSIDs for initial open hotspot than for "final" hostspot 'cause Android gets
    # confused when it switches from password-less to w/password.
    # FIXME: should also set the country code, but there may not be a NETWORK.TXT file
    # But the "global" country code 00 is probably just fine
    SSID=$(cat /etc/sensorgnome/id)
    egrep -q wpa=0 /etc/hostapd/hostapd.conf && SSID="$SSID-init"
    sed -i -e "s/^ssid=.*/ssid=$SSID/" /etc/hostapd/hostapd.conf

    echo "Starting up Wifi HotSpot, SSID=$SSID"
    rfkill unblock wlan # prob not necessary but harmless

    # Ensure we have a device for the AP
    if ! ip link show ap0 2>/dev/null; then
        iw dev wlan0 interface add ap0 type __ap
        sleep 2
        while ! ip link show ap0 2>/dev/null; do
            sleep 2 # seems to take time... hostapd fails if the dev isn't there
        done
    fi

    # Ensure resolvconf doesn't pick up on the dnsmasq we're about to start
    if ! egrep -q lo.dnsmasq /etc/resolvconf.conf; then
        echo "# prevent captive portal dnsmasq from becoming a resolver" >> /etc/resolvconf.conf
        echo "deny_interfaces=lo.dnsmasq" >> /etc/resolvconf.conf
        resolvconf -u
    fi

    systemctl start hostapd
    systemctl start dnsmasq

    # Set-up captive portal
    iptables -t nat -D $ipt_reset 2>/dev/null || true
    iptables -t nat -A $ipt_self
    iptables -t nat -A $ipt_route
else
    echo "Cannot start WiFi Hotspot: there is no AP capable adapter present"
fi
