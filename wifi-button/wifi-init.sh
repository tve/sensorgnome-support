#! /usr/bin/bash -e

echo "Unblocking wlan"
rfkill unblock wlan # prob not necessary but harmless, always do this
rfkill unblock wifi # prob not necessary but harmless, always do this

# Make sure the wlan0 interface exists, this should be done by waiting for the appropriate
# systemd something, but not obvious what that is
ls /var/lib/systemd/rfkill
echo kill is $(cat /var/lib/systemd/rfkill/*wlan)
if ! wpa_cli interface | grep -q wlan0; then sleep 5; fi
if ! wpa_cli interface | grep -q wlan0; then sleep 5; fi

# Set wifi country to global if not set
if wpa_cli -i wlan0 get country | egrep -q FAIL; then
    echo "Setting wifi country to global"
    wpa_cli -i wlan0 set country 00
fi

# Set wifi client to something otherwise it's in DISCONNECTED instead of INACTIVE state
# and that confuses the dashboard
if ! egrep -q "network=" /etc/wpa_supplicant/wpa_supplicant.conf; then
    echo "Setting wifi client to sample network"
    wpa_cli -i wlan0 add_network wlan0
    wpa_cli -i wlan0 set_network wlan0 ssid '"my_ssid"'
    wpa_cli -i wlan0 set_network wlan0 key_mgmt NONE
    wpa_cli -i wlan0 disable 0
    wpa_cli -i wlan0 save_config
    cat /etc/wpa_supplicant/wpa_supplicant.conf
else
    wpa_cli -i wlan0 reconnect # will force INACTICVE state if all networks are disabled
fi
