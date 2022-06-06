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
