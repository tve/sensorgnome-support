#! /usr/bin/python

import json
import sys
import time
import traceback
from power_api import SixfabPower, Definition as sfp
pwr = SixfabPower()

shutdown_level = 95 # battery capacily % at which to shut down

# Read the firmware version a couple of time to see whether we have a Sixfab UPS HAT.
# Due to stacking HATs the EEPROM is not reliable.
v = None
try:
    v = pwr.get_firmware_ver().rstrip("\x00")
except Exception:
    time.sleep(1)
    try:
        v = pwr.get_firmware_ver().rstrip("\x00")
    except Exception as e:
        print("Error reading Sixfab UPS HAT version", file=sys.stderr)
        sys.exit(1)
#print("Firmware:", v)

try:
    # Set the max battery charge level to 99%. This ends up being around 4.11V for a 2600mAh 18650
    # which extends battery life quite noticeably compared to a hot 4.2V.
    # (98% ends up being just over 4V.)
    mcl = pwr.get_battery_max_charge_level()
    if mcl != 99:
        pwr.set_battery_max_charge_level(99)

    # Configure a watchdog timer to reboot the Pi if this script isn't being run at least once
    # every 10 minutes. This avoid running the battery down if the Pi hangs.
    wi = pwr.get_watchdog_interval()
    if wi != 10:
        pwr.set_watchdog_interval(10)
    ws = pwr.get_watchdog_status()
    if ws != 1:
        pwr.watchdog_signal()
        pwr.set_watchdog_status(1) # 1=enable 2=disable watchdog

    # Figure out whether it's time to call it quits, i.e. shut down in order to avoid killing the
    # Lithium battery. You'd be forgiven to think that a UPS HAT would be able to tell us this...
    # We shut down when the battery level reaches a couple of percent and there is no power
    # coming in to charge it.
    ivolt = pwr.get_input_voltage()
    ipwr = pwr.get_input_power()
    lvl = pwr.get_battery_level()
    shutdown = ivolt < 5 and ipwr < 0.1 and lvl <= shutdown_level

    # Prep things to shutdown, or not. For shutdown, we need to set the "power outage params" which
    # cycle the Pi off (sleep) for N minutes and then on (run) for M minutes. We don't care about
    # this cycling but we need to set it so that the HAT turns the Pi back on when power is restored.
    # Note that in this context "power outage" means no power coming in to charge the battery.
    if shutdown:
        pwr.set_power_outage_params(sleep_time=1439, run_time=3)
        pwr.set_power_outage_event_status(1) # 1=enabled
    else:
        pwr.set_power_outage_event_status(2) # 2=disabled
    pwr.watchdog_signal()

    # Query various stats from the UPS hat and construct a json response object
    data = {"firmware": {"ver": v}}
    for subsys in ["input", "system", "battery"]:
        data[subsys] = {}
        for key in ["temp", "voltage", "current", "power"]:
            f = f"get_{subsys}_{key}"
            data[subsys][key] = getattr(pwr, f)()

    for key in ["level", "health", "max_charge_level", "design_capacity"]:
        f = f"get_battery_{key}"
        data["battery"][key] = getattr(pwr, f)()

    data["battery"]["shutdown_level"] = pwr.get_safe_shutdown_battery_level()
    w_modes = ["unknown", "charging", "charged", "discharging"]
    data["battery"]["mode"] = w_modes[pwr.get_working_mode()]

    data["fan"] = {}
    data["fan"]["speed"] = pwr.get_fan_speed()
    data["fan"]["health"] = pwr.get_fan_health()
    data["shutdown"] = shutdown

    print(json.dumps(data))

    # This shutdown code is a last resort only. Under normal operation the caller,
    # i.e. sg-control, will shut down the Pi.
    if lvl < 1 and shutdown:
        print("Shutting down...", file=sys.stderr)
        time.sleep(3)
        import os
        os.system("sudo shutdown -h now")

except Exception as e:
    print("Error:", e, file=sys.stderr)
    traceback.print_exc()
    sys.exit(1)
