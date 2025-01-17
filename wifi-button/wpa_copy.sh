#!/bin/sh
# Copied from bullseye

mv /boot/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
REGDOMAIN=$(sed -n 's/^\s*country=\(..\)$/\1/p' /etc/wpa_supplicant/wpa_supplicant.conf)
[ -n "$REGDOMAIN" ] && raspi-config nonint do_wifi_country "$REGDOMAIN"
# raspi-config nonint do_netconf 1 -- no longer exists in bookworm
