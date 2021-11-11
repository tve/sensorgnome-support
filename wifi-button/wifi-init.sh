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
echo "Unblocking wlan"
rfkill unblock wlan # prob not necessary but harmless
echo "Setting wlan country"
raspi-config nonint do_wifi_country $WIFI_COUNTRY
echo "Setting wlan ssid/passphrase"
raspi-config nonint do_wifi_ssid_passphrase $WIFI_SSID $WIFI_PASS
echo "Done"

# Using: https://www.raspberrypi.com/documentation/computers/configuration.html#using-the-command-line
#sed -i -e "s/ssid=.*/ssid=\"$WIFI_SSID\"/" \
#       -e "s/psk=.*/psk=\"$WIFI_PASS\"/" \
#       -e "s/country=.*/country=$WIFI_COUNTRY/" \
#       /etc/wpa_supplicant/wpa_supplicant.conf
#rfkill unblock wlan # prob not necessary but harmless
#id=$(wpa_cli -i wlan0 add_network )
#wpa_cli -i wlan0 reconfigure
