Sensorgnome WiFi
================

Scripts and config to enable/disable WiFi client and WiFi hot-spot.
The scripts/code in this directory provide a customized experience around configuring
and enabling WiFi. In the end, they configure and enable/disable features using the
standard tools. On rPi this means:

- [WiFi client set-up using cli](https://www.raspberrypi.com/documentation/computers/configuration.html#using-the-command-line)
- [routed hot-spot set-up](https://www.raspberrypi.com/documentation/computers/configuration.html#setting-up-a-routed-wireless-access-point) (this is not the exact set-up used)

The Sensorgnome WiFi client is configured using a `network.txt` config file. This file is
typically placed in the fat32 /data partition so it can be edited on a windows laptop.
The WiFi client is enabled at boot if config is provided, after that the std `wpa_supplicant`
daemon manages it.

The Sensorgnome hot-spot is enabled via a hardware button that is polled using the `gestures.js`
and `pushbutton.js` scripts. The hot-spot configuration is fixed and uses the Sensorgnome's ID.
The button and associated LED pins can be configured in `gestures.txt` to a limited degree.

Notes:

- The WiFi client and the hot-spot are almost completely independent and can operate simultaneously,
  enabling/disabling one has almost no effect on the other (it appears that when the hot-spot is
  disabled then the client connection briefly drops as well before it gets re-established).
- If the `network.txt` is configured on a running system typically a reboot is necessary for the
  changes to take effect, it _may_ be possible for them to take effect immediately if one runs
  `sudo systemctl restart WiFi-init`.
- If WiFi client and hot-spot are enabled at the same time, then the channel used depends on the
  client side (i.e. the access point being connected to). Beware that this may be a 5Ghz channel
  and thus the hot-spot may also be on 5Ghz.
- If the WiFi hot-spot is enabled without WiFi client connection the channel used is No.1

Dev notes
---------

(See also top-level README.)

The hotspot starts dnsmasq to respond to DNS queries from clients, which is a required feature,
and it responds with 192.168.7.2 to every query (captive portal). By default resolvconf picks
up on the fact that dnsmasq is running and sets /etc/resolv.conf to point to it, which breaks
all DNS resolutions. This package adds "deny_interfaces=lo.dnsmasq" to /etc/resolvconf.conf
to prevent that.

The `sg-WiFi-button.deb` package can be installed and tested on a vanilla rPi provided the following
are present:

- /etc/sensorgnome directory must exist (`sudo mkdir -p /etc/sensorgnome`)
- /etc/sensorgnome/id is initialized (ex: `echo 1234RPI45678 | sudo tee /etc/sensorgnome/id`)
- a reboot is necessary after the first install before testing to get the device tree overlay loaded

About all the files here... There are four groupings:

- `etc-*` files are config snippets for standard daemons that find their way into `/etc/...`
- `gestures*` are files related to the daemon that polls the button and blinks the LED
- `gpio*` are files to init the GPIO pins used by the gestures daemon
- `WiFi*` are files that handle WiFi client and hot-spot configuration
