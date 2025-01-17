Udev rules for USB devices
==========================

The udev rules and "portnums" files in this directory handle the numbering of USB
ports such that receivers plugged into ports can be identified and associated with
antennas and their orientation.

The funcdamental problem is that neither the FUNcube dongkles nor the CTT receivers
have any unique ID or serial number that is computer-readable. Given that a typical
station has multiple receivers of the same type plugged in we need some way to
associate each receiver seen by the sensorgnome code with an antenna and its orientation.

The solution employed here is to number the ports in a predicatble manner for USB hubs
that are known and thereby allow the user to specify that "receiver plugged into port
N is for an antenna pointing in direction X".

Unfortunately this solution is very brittle because the numbering is specific for each
USB hub model as well as for each type of host computer.

Operation
---------

The `usb-hub-devices.rules` file matches the signatures of devices plugged in
with `portnums` files.
For each type of hub, we need a file called hub_MODELNAME_portnums.txt
which maps usb device path prefixes to usb port numbers.  When a
particular USB hub is detected, we symlink /dev/usb_hub_port_nums.txt
to one of those files.  When other usb devices are detected, udev
rules are set up to create sensible symlinks in /dev/sensorgnome.

eg.:
- `/dev/sensorgnome/disk.port=2.name=sdb1`
- `/dev/sensorgnome/funcube.port=6.alsaDev=0.libusbPath=1:12` (in usb port 6 is alsa dev 0)
- `/dev/sensorgnome/gps.port=4`

On the beaglebone, an external USB hub generates this udev event upon
detection: 
`add, %p = /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1, %k = 1-1`

### GWC HU2SA0R 10-port USB hub
Adds two devices to lsusb:
```
1a40:0201 TERMINUS TECHNOLOGY INC. 
1a40:0101 TERMINUS TECHNOLOGY INC. 
```
(the first is a 7 port hub, the 2nd is a 4 port hub hanging off the last port
of the first device).

```
Physical Layout
Top View:
   +-----------------------------------------+
   |   DC    mini   1      2      3      4   |
   |  Jack     B			     |
   |					     |
   |           USB 2.0 10-port Hub	     |
   |					     |
   |  5      6      7      8      9     10   |
   +-----------------------------------------+


port num   Kernel path (%p parameter in udev rules)  HU2SA0R

   1       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.1/
   2       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.2/
   3       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.3/
   4       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.4/
   5       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.5/
   6       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.6/
   7       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.7/1-1.7.4
   8       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.7/1-1.7.3
   9       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.7/1-1.7.2
  10       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.7/1-1.7.1
```

### DLink DUB-H7  (P/N CUBH7LB...B1)
Adds two devices to lsusb: 
```
05e3:0610 Genesys Logic, Inc.
05e3:0610 Genesys Logic, Inc.
```
These are the two 4 port hubs,
one hanging off the first port of the other.
```
Physical layout:
Front View:
+-------------------------------+
|   1    2   3   4   5   6   7  |
+-------------------------------+

Back View:
+-------------------------------+
|   +5VDC   USB-B               |
+-------------------------------+

port num   Kernel path (%p parameter in udev rules)  DUB-H7

   1       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.1/1-1.1.1 
   2       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.2 
   3       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.1/1-1.1.2
   4       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.3
   5       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.1/1-1.1.3
   6       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.4
   7       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.1/1-1.1.4
```

### Staples-branded Belkin 7-port USB Hub
Adds one device in lsusb:
```
050d:0416 Belkin Components 
```
which is a 7 port USB hub.
```
Physical Layout:
Top View:
   
             ________________________________
           _/    5     4     3     2     1   \_
          /                                    \
          |+ 5VDC                       mini-B | 
          |                                    |
          |    --6--                   --7--   | 
          \_                                 _/
            \_______________________________/
          
port num   Kernel path (%p parameter in udev rules)  Staples/Belkin 7-port

   1       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.1
   2       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.2
   3       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.3
   4       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.4
   5       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.5
   6       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.6
   7       /devices/platform/omap/musb-ti81xx/musb-hdrc.1/usb1/1-1/1-1.7
```

### UUGEAR (http://uugear.com) 7 port Pi Hub

Terminus Tech 7-port hub plugged into port 4 of RPI-2.
This device looks like this in lsusb:
```
   ID 1a40:0201 Terminus Technology Inc. FE 2.1 7-port Hub
```
In this situation, ports 1-3 of the Pi are still labelled 1, 2, and 3,
but the 7 ports on the hub are labelled like this:
```
   6  5  4
   +======
 7 |     |
   +======
   8  9  0
```
(i.e. the 1st port on the hub replaces port 4 on the Pi)
