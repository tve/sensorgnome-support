Sensorgnome support
===================

Support packages needed for a Sensorgnome to operate.

This repository contains a collection of subsystems, each in its own directory, that are needed
for a Sensorgnome to operate. The subsystems are intended to be packaged as standard `.deb` and
contain all the pieces necessary. Each subsystem package should be upgradable
independently as much as possible using the standard debian `apt install` machinery.

One of the purposes of slicing the support functionality into a number of packages is that different
hardware implementations of a Sensorgnome can mix and match the support packages they need.

The current subsystems are:
- funcube: tools related to funcube dongles
- gps-clock: scripts to manage GPS, real-time clock, and system clock synchronization
- sg-boot: misc pieces to init a sensorgnome
- ssh-tunnel: maintain communication channels over SSH
- udev-usb: manage USB devices, incl hubs
- wifi-button: manage wifi client and hotspot using a physical button and LED indicator

The `unused` directory contains files from prior versions that are currently unused.

Development
-----------

- To test&dev it's helpful to have an rPi with a clean Raspberry Pi 'lite' OS installation.
  Download the image from the raspberry site and save it locally. Then flash an SDcard and
  edit the `init-rpi.sh` script's variables at the top of the file. Running that script
  preps the rpi image (after flashing is complete you have to pull & re-insert the SDcard
  so its filesystems get mounted before you can run the script).
  The script works on linux, it should be possible to make it work on Mac, prob also on WSL.
  Patches appreciated...
- After running the `init-rpi.sh` script, it is recommended to boot the rPi, log in and run
  `sudo apt update; sudo apt upgrade`.
- Each subsystem subdir has a `doit` script that creates the debian package for the subsystem
  uploads the deb to an rPi, installs it, and restarts appropriate services to see the subsystem
  initialize. Most subsystems require that the `sg-boot` be installed and run first. In their
  current form the doit scripts all need tweaking to adapt to your work environment.
- Each subsystem subdir has a `gen_package.sh`  script that generates the debian package for
  the subsystem. In order to ensure consistent access to the debian packaging tools this
  script should be run in a dockcross container. See the `doit` scripts for examples.
  The dockcross container image (and associated script) can be installed using the
  sensorgnome-build repo.
- Assuming you have `sensorgnome-build` checked-out alongside this repo you might run
  `gen_package.sh` as follows (from within one of the subdirs of this repo):
```
    ../../sensorgnome-build/docker/sensorgnome-armv7-rpi-buster ./gen_package.sh
```

Open issues
-----------

1. The FAT32 data partition is created on first boot, more precisely, when the sg-boot service
   first runs. It creates the partition in the free space on the SDcard. What should happen if
   the SDcard has no free space because someone installed stuff on an existing rPi OS install?
   Two options: silently continue with /data being on the root partition, or abort with error?
1. What should happen with a hotspot if there is no gestures.txt, i.e., no button? Always turn
   hotspot on and if so, for how long?
1. The service unit sequencing needs to be revisited.
1. Need to ensure that the time is set to some obvious bogus value until there is proper
   time sync so it's easy to flag detections where there is no correct time.
1. Need to check the data usage for cell-based stations, in particular the cost of keep-alives.
1. Need to revisit the USB port numbering machinery.
1. Need to revisit USB watchdog.
