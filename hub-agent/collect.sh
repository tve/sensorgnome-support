#! /bin/bash
# Simple script to collect a bunch of operating system info and output it
# in a simple format on stdout.

echo "date: $(date +%s) $(date -u)"
echo -n "sgid: "
cat /etc/sensorgnome/id
echo -n "timezone: "
tail -1 /etc/localtime
echo -n "bootcount: "
cat /etc/sensorgnome/bootcount
echo -n "label: "
jq .label /etc/sensorgnome/acquisition.json
echo -n "lotek_freq: "
jq .lotek_freq /etc/sensorgnome/acquisition.json
echo "find_tags: " $(jq .module_options.find_tags.params /etc/sensorgnome/acquisition.json)
echo -n "version: "
cat /etc/sensorgnome/version
echo -n "train: "
awk '{print $3}' </etc/apt/sources.list.d/sensorgnome.list

echo -n "default route: "
ip route get 1.1.1.1 | head -1

echo
echo "ip addresses"
ip addr
echo
echo "route table"
ip route
echo
echo "wifi"
wpa_cli status
echo

echo chrony
chronyc -n sources
echo

echo packages
sg="$(dpkg -s sensorgnome)"
echo "pkg sensorgnome:" $(echo "$sg" | grep Version | cut -d' ' -f2)
deps=$(echo "$sg" | grep Depends | sed -E -e 's/.*: //' -e 's/([(][^)]*[)])?,*//g')
#echo "dependencies: $deps"
for d in $deps; do
   echo "pkg $d: $(dpkg -s $d | grep Version | cut -d' ' -f2)"
done
echo

echo services
for s in sg-control sg-web-portal gpsd gestures caddy chrony telegraf wpa_supplicant hostapd; do
   echo "$s: $(systemctl status $s | grep Active)"
done
echo

echo usb
lsusb
echo

echo vnstat
vnstat
echo
