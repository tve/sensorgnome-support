SixFab HAT support (GPS & UPS)
============================

This directory contains support for the Sixfab "Raspberry Pi 4G/LTE Cellular Modem HAT" and
the Sixfab "Power management & UPS HAT".

Cheat sheet for all buttons and LEDs:
https://docs.google.com/spreadsheets/d/1LPCTtBtX-1I8b2Jpw2137RnhGbd2eT4Sk81jD0RiH5c


**The code in this directory has been effectively disabled!**

The cellular modem is managed "generically" using `../cellular` and the UPS HAT is not supported
anymore because it's API is too flakey to be usable. The only thing remaining here that is used
is the detection of the SixFAB base (cellular) HAT 'cause that's used to enable the user button
to trigger the hot-spot.

Cellular Modem HAT
-----------------

The presence of the HAT is detected by the appearance of a USB cellular modem device, see
`30-sixfab.rules`. In principle, the HAT contains an EEPROM as well and its content could be
read to detect the HAT presence, however in a stack-up with the UPS HAT the two EEPROMs in the
two HAT conflict and the data being read is garbled (great, huh?).

The install uses a ZIP file with a snapshot of the Sixfab "core manager", which configures the
cellular modem and ensures that it maintains a connection. This provides "plain" internet
connectivity. The Sixfab "core agent", which provides remote monitoring and remote access
is not installed. If desired, it can be installed manually by following the directions in the
Sixfab HAT manual.

The cellular HAT has a "user button" and a "user LED", these are configured as described in the
Sensorgnome docs to turn Wifi Hotspot on/off and to indicate hotspot status.

rPi GPIO pins:
- 27: user LED, active high
- 22: user button, active low, has pull-up
- 6: ring indicator (incoming SMS or call)
- 13: DTR, pull-low to wake module when in sleep mode
- 19: airplane mode enable, active high
- 26: power-down module, active high

Power management & UPS HAT
-------------------------

- microcontroller: Atmel SAMD21 (G18A-U)
- battery charger: Ti BQ25703A
- fuel gauge: Ti BQ27441A
- input mosfet: OnSemi FDMC510P
- other: Ti 2S402, Ti CDS17551, HK7AA, B219
