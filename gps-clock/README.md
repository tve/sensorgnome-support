Sensorgnome GPS Clock and Location
==================================

Manage the system clock using chrony and a GPS with GPSd:

- set-up chrony to handle internet time servers as well as interface with GPSd
- set-up GPSd to handle the Adafruit GPS HAT
- set-up GPSd to produce location updates where the sensorgnome master process finds it

A good summary of setting up chrony/gps/gpsd can be found at:
https://wiki.alpinelinux.org/wiki/Chrony_and_GPSD.
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

Note: the battery backup ought to last around 7 months (if the SG has no power),
so better pull the battery if the SG goes into storage or have a fresh battery handy
when it goes back into operation.

Troubleshooting
---------------

Running `gpsmon` provides info from gpsd. The RMC box shows the time (in seconds since ?) and the
fix status (A=Valid, V=Invalid (!)). The GGA box shows the number of satellites received. The GSA+PPS
box shows the time offset of the NMEA sentences (9600 baud...) and the accuracy of the PPS
signal in seconds.

Running `sudo ntpshmmon` displays the info passed from gpsd to chrony via shared memory.
The NTP0 lines correspond to basic NMEA stanzas, the NTP2 lines to PPS.

Running `chronyc sources` (or `watch chronyc sources`) shows what chrony thinks.
A `*` in the second character column indicates the current locked on source.
A `x` indicates the backup source.
The NMEA source is just the serial data, which is delayed and a bit inaccurate.
The PPS source is the most accurate, if there is a good fix.

Dev notes
---------

(See also top-level README.)

The `sg-gps-clock.deb` package can be installed and tested on a vanilla rPi with the following
considerations:

- TBD
- you can typically revert a run of `sg-gps-clock` as follows:

```bash
sudo apt remove -y gpsd chrony
```

### Detect clock time step

See [stackoverflow](https://stackoverflow.com/questions/2251635)

```C
#include <sys/timerfd.h>
#include <limits.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>

int main(void) {
        int fd = timerfd_create(CLOCK_REALTIME, 0);
        timerfd_settime(fd, TFD_TIMER_ABSTIME | TFD_TIMER_CANCEL_ON_SET,
                        &(struct itimerspec){ .it_value = { .tv_sec = INT_MAX } },
                        NULL);
        printf("Waiting\n");
        char buffer[10];
        if (-1 == read(fd, &buffer, 10)) {
                if (errno == ECANCELED)
                        printf("Timer cancelled - system clock changed\n");
                else
                        perror("error");
        }
        close(fd);
        return 0;
}
```
