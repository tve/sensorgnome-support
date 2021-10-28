Sensorgnome GPS Clock and Location
==================================

Manage the system clock using chrony and a GPS with GPSd:
- set-up chrony to handle internet time servers as well as interface with GPSd
- set-up GPSd to handle the Adafruit GPS HAT
- set-up GPSd to produce location updates where the sensorgnome master process finds it

A good summary of setting up chrony/gps/gpsd can be found at:
https://wiki.alpinelinux.org/wiki/Chrony_and_GPSD
A good blog post is at:
https://austinsnerdythings.com/2021/04/19/microsecond-accurate-ntp-with-a-raspberry-pi-and-pps-gps/

Troubleshooting
---------------

Running `gpsmon` provides info from gpsd. The RMC box shows the time (in seconds since ?) and the
fix status (A=Valid, V=Invalid (!)). The GGA box shows the number of satellites received. The GSA+PPS
box shows the time offset of the NMEA sentences (9600 baud...) and the accuracy of the PPS
signal in seconds.

Running `chronyc sources` (or `watch chronyc sources`) shows what chrony thinks. A `*` in the second
character column indicates the current locked on source. A `x` indicates the backup source. The
NMEA source is just the serial data, which is delayed and a bit inaccurate. The PPS source is the
most accurate, if there is a good fix.

**The following doesn't work yet...**
If the backup battery is installed in the GPS and the rPi is cold started without internet
and without satellites in sight then `chronyc sources` should show non-zero `lastRx` for the
NMEA source, which corresponds to the time from the battery-backed RTC. The PPS source will show no `lastRx`.
`gpsmon` should show the current date in DD,MM,YYYY format the GPZDA stanza.

Development
-----------

The `sg-gps-clock` package can be built using the `gen_package.sh` script. It requires a couple of
debian tools so it's best run inside of a dockcross container. Assuming you have `sensorgnome-build`
checked-out alongside this repo this might look as follows:
```
../../sensorgnome-build/docker/sensorgnome-armv7-rpi-buster ./gen_package.sh
```

The `sg-gps-clock.deb` package can be installed and tested on a vanilla rPi with the following
considerations:
- TBD
- you can typically revert a run of `sg-gps-clock` as follows:
```
sudo apt remove -y gpsd chrony
```

For test&dev the `doit` script can be used to generate a fresh package, upload it to a nearby
rPi, install it, and restart appropriate services. It assumes that the
`sensorgnome-armv7-rpi-buster` dockcross script/image is available and it has a hardcoded
rPi hostname that you will need to adapt. (You will also want to set your rPi up with ssh
key-based auth so you don't have to type a password 10 times...)
