## compile and install an overlay to allow use of an LED-lit
## pushbutton switch such as:  https://www.adafruit.com/product/559
##
## We use gpio17 to power the LED, and gpio18 to read the switch.
## The overlay serves mainly to enable the internal pull-up resistor
## on gpio18, so we don't have to use an external one.

all: gpio_pull.dtbo

# Overlay to enable pull-up on pushbutton GPIO
gpio_pull.dtbo: gpio_pull-overlay.dts
	dtc -@ -I dts -O dtb -o $@ $<

# Installation moves files to where they need to go
DEST=$(DESTDIR)/opt/sensorgnome/wifi-button
DATA_CONFIG=/data/config
install: gpio_pull.dtbo
    # install in sensorgnome dir
	install -d $(DEST) $(DEST)/scripts $(DEST)/misc $(DEST)/DEBIAN
	install -m 644 *.js $(DEST)/scripts
	install -m 755 *.sh $(DEST)/scripts
	install -m 644 gpio_pull.dtbo $(DEST)/misc
	install -m 644 *.TXT $(DEST)/misc
	install -m 644 etc-dhcpcd.conf $(DEST)/misc
    # install in system location
	install -d $(DESTDIR)/etc/wpa_supplicant $(DESTDIR)/etc/hostapd
	install -d $(DESTDIR)/etc/systemd/system $(DESTDIR)/etc/dnsmasq.d
	install -d $(DESTDIR)/boot $(DESTDIR)/boot/overlays
	install -m 644 *.service $(DESTDIR)/etc/systemd/system
	install -m 644 etc-dnsmasq.conf $(DESTDIR)/etc/dnsmasq.d/wifi-button.conf
	install -m 644 etc-hostapd.conf $(DESTDIR)/etc/hostapd/hostapd.conf
	install -m 644 etc-wpa_supplicant.conf $(DESTDIR)/etc/wpa_supplicant/wpa_supplicant.conf
