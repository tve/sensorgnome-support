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
- ssh-comms: maintain communication channels over SSH
- udev-usb: manage USB devices, incl hubs
- wifi-button: manage wifi client and hotspot using a physical button and LED indicator

The `unused` directory contains files from prior versions that are currently unused.
