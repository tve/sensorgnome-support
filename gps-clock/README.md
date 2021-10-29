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

Operation
---------

The clock synchronization is performed by chrony. If there's network connectivity, it will use
NTP automatically. Otherwise, a GPS HAT or RTC (real-time-clock) better provide time. The latter
two are handled by gpsd expecting an Adafruit GPS HAT to be available. (Plugging a random USB GPS
in may also work, untested...)

If the GPS has a fix, then gpsd will send NMEA stanzas to chrony, shown as "NMEA" source in
`chronyc sources`.
Because of the low baud rate, this is not very accurate (but far better than nothing).
Some combination of gpsd and the kernel PPS-gpio driver will also produce PPS (pulse per second)
information with very high accuracy (~1ms) for chrony. This is shown as "PPS" source in chrony.

If the GPS has no fix but a battery is inserted into the HAT and the RTC has been synchronized
by the GPS previously then gpsd will produce NMEA stanzas with the RTC time (option `-r` to gpsd).
Chrony will use this to sync time and we hope the RTC time is reasonably accurate.

If the GPS HAT has no fix and there's no battery (and there's no NTP server reachable) then gpsd
will propagate the RTC-based time it gets from the GPS module, which is sometime in 1980...
Chrony is configured not to step the clock more than 10 years, so if the rPi has previously shut
down with a recent time/date then chrony will refuse to set the clock back and eventually exit
to be restarted by systemd again.

If none of these things set the clock, then the initial boot clock is used, which is the linux
"fake-hwclock", which means it's the time saved when the rPi was shut down (plus perhaps some guesstimate adjustment).


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
