#! /usr/bin/bash -e
#
# If data/config/NETWORK.TXT exists, try to grab an SSID and passphrase
# from it and set up the SG as a WiFi client.
# If the file does not exist or does not contain SSID/passphrase then
# do not wifi client config.
#
# Also set-up parameters for Wifi hotspot.

# Accepts one argument, which is the directory where NETWORK.TXT is found
DIR=${1:-/data/config}
FN=NETWORK.TXT

if [[ ! -f $DIR/$FN ]]; then
  echo "No file $DIR/$FN found: not touching Wifi"
  exit 0
fi

# Extract Wifi info from config file

WIFI_SSID="$(grep '^WIFI_SSID=' $DIR/$FN | sed -e 's/^WIFI_SSID=//' -e 's/^"\(.*\)"$/\1/')"
WIFI_PASS="$(grep '^WIFI_PASS=' $DIR/$FN | sed -e 's/^WIFI_PASS=//' -e 's/^"\(.*\)"$/\1/')"
WIFI_COUNTRY="$(grep '^WIFI_COUNTRY=' $DIR/$FN | sed -e 's/^WIFI_COUNTRY=//' -e 's/^"\(.*\)"$/\1/')"

if [ -z "$WIFI_SSID" -o -z "$WIFI_PASS" ]; then
  echo "No Wifi SSID and/or no passphrase: not touching Wifi"
  exit 0
fi

WIFI_COUNTRY=${WIFI_COUNTRY:-US}

# Configure the wifi client
# Using: https://www.raspberrypi.com/documentation/computers/configuration.html#using-the-command-line
sed -i -e "s/ssid=.*/ssid=\"$WIFI_SSID\"/" \
       -e "s/psk=.*/psk=\"$WIFI_PASS\"/" \
       -e "s/country=.*/country=$WIFI_COUNTRY/" \
       /etc/wpa_supplicant/wpa_supplicant.conf
rfkill unblock wlan # prob not necessary but harmless
wpa_cli -i wlan0 reconfigure

# mkdir -p /etc/wpa_supplicant
# cat <<"EOF" >/etc/wpa_supplicant/wpa_supplicant.conf
# ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
# update_config=1
# country=$WIFI_COUNTRY
# network={
#     ssid="$WIFI_SSID"
#     psk="$WIFI_PASS"
# }
# EOF
# wpa_cli -i wlan0 reconfigure
# 
# # /etc/dhcpcd.conf
# interface ap0
# static ip_address=192.168.7.2/24
# nohook wpa_supplicant
# 
# # hostapd.conf
# country_code=US
# interface=ap0
# ssid=sg-hotspot
# hw_mode=g
# channel=1
# macaddr_acl=0
# auth_algs=1
# ignore_broadcast_ssid=0
# wpa=2
# wpa_passphrase=sg-hotspot
# wpa_key_mgmt=WPA-PSK
# wpa_pairwise=TKIP
# rsn_pairwise=CCMP
# 
# # /etc/dnsmasq.conf
# interface=ap0
# dhcp-range=192.168.7.10,192.168.7.20,255.255.255.0,24h
# domain=local
# address=/sg.local/192.168.7.2
