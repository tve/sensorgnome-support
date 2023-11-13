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
- funcube: tools related to funcube dongles, primarily to update the firmware, this is not
  actively used
- gps-clock: scripts to manage GPS, real-time clock, and system clock synchronization
- hub-agent: simple agent that, together with [telegraf](https://github.com/influxdata/telegraf/)
  sends monitoring data to the [SG hub](www.sensorgnome.net) and facilitates remote management
- sensorgnome: umbrella package that depends on all the other packages and is used to install
  or upgrade all the other packages
- sg-boot: misc pieces to init a sensorgnome
- sixfab: software related to the SixFab cellular HAT, this is not used anymore and ModemManager
  is used instead; this dir also has old code for the SixFab UPS HAT, which is not used anymore
- udev-usb: manage USB devices, incl hubs, this mainly sets up the rules for udev
- upgrader: small set of scripts to upgrade the sensorgnome, invoked through the web ui
- web-portal: very simple web app that is used for the initial installation of the software,
  it presents redirect pages and a simple form to set a password and short-name before
  the main control process and its web app can be accessed
- wifi-button: manage wifi client and hotspot using a physical button and LED indicator

Development
-----------

- To test & dev it's helpful to have an rPi with a clean Raspberry Pi 'lite' OS installation.
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
    ../../sensorgnome-build/docker/sensorgnome-armv7-rpi-bullseye ./gen_package.sh
```

Open issues
-----------

1. The FAT32 data partition is created on first boot, more precisely, when the sg-boot service
   first runs. It creates the partition in the free space on the SDcard. What should happen if
   the SDcard has no free space because someone installed stuff on an existing rPi OS install?
   Two options: silently continue with /data being on the root partition, or abort with error?
   (A: currently the latter.)
1. Need to ensure that the time is set to some obvious bogus value until there is proper
   time sync so it's easy to flag detections where there is no correct time.
1. The organization of the repo into subdirectories with mostly independent subsystems seems
   to work very well. However, whether it makes sense for each subdir to produce its own deb
   package is questionable. The intent is to be able to install just the needed packages on
   each target platform. But it turns into a ton of tiny packages. An alternative might be to
   have a very simple config file that specifies which subsystems should be rolled into one
   single package for each target.
