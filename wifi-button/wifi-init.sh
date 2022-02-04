#! /usr/bin/bash -e

echo "Unblocking wlan"
rfkill unblock wlan # prob not necessary but harmless, always do this

# Set wifi country to global if not set
if wpa_cli -i wlan0 get country | egrep -q FAIL; then
    echo "Setting wifi country to global"
    wpa_cli -i wlan0 set country 00
fi
