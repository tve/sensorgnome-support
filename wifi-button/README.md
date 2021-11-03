Sensorgnome Wifi
================

Scripts and config to enable/disable Wifi client and Wifi hotspot.
The scripts/code in this directory provide a customized experience around configuring
and enabling Wifi. In the end, they configure and enable/disable features using the
standard tools. On rPi this means:
- https://www.raspberrypi.com/documentation/computers/configuration.html#using-the-command-line
- https://www.raspberrypi.com/documentation/computers/configuration.html#setting-up-a-routed-wireless-access-point

The Sensorgnome WiFi client is configured using a `NETWORK.TXT` config file. This file is
typically placed in the fat32 /data partition so it can be edited on a windows laptop.
The Wifi client is enabled at boot if config is provided, after that the std `wpa_supplicant`
daemon manages it.

The Sensorgnome hotspot is enabled via a hardware button that is polled using the `gestures.js`
and `pushbutton.js` scripts. The hotspot configuration is fixed and uses the Sensorgnome's ID.
The button and associated LED pins can be configured in `GESTURES.TXT` to a limited degree.

Notes:
- The wifi client and the hotspot are almost completely independent and can operate simultaneously,
  enabling/disabling one has almost no effect on the other (it appears that when the hotspot is
  disabled then the client connection briefly drops as well before it gets re-established).
- If the NETWORK.TXT is configured on a running system typically a reboot is necessary for the
  changes to take effect, it _may_ be possible for them to take effect immediately if one runs
  `sudo systemctl restart wifi-init`.
- If wifi client and hotspot are enabled at the same time, then the channel used depends on the
  client side (i.e. the access point being connected to). Beware that this may be a 5Ghz channel
  and thus the hotspot may also be on 5Ghz.
- If the wifi hotspot is enabled without wifi client connection the channel used is No.1

Dev notes
---------
(See also top-level README.)

The `sg-wifi-button.deb` package can be installed and tested on a vanilla rPi provided the following
are present:
- /data/config directory must exist (`sudo mkdir -p /data/config`)
- /etc/sensorgnome_id is initialized (ex: `echo 1234RPI45678 | sudo tee /etc/sensorgnome_id`)
- a reboot is necessary after the first install before testing to get the device tree overlay loaded

About all the files here... There are four groupings:
- `etc-*` files are config snippets for standard daemons that find their way into `/etc/...`
- `gestures*` are files related to the daemon that polls the button and blinks the LED
- `gpio*` are files to init the GPIO pins used by the gestures daemon
- `wifi*` are files that handle wifi client and hotspot configuration
