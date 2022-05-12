#! /usr/bin/python

import json
import sys
from power_api import SixfabPower
pwr = SixfabPower()

try:
    v = pwr.get_firmware_ver().rstrip("\x00")
    #print("Firmware:", v)
    pwr.set_battery_max_charge_level(95)
except Exception as e:
    print("Error:", e, file=sys.stderr)
    print("Assuming no Sixfab UPS HAT present", file=sys.stderr)
    sys.exit(1)


data = {"firmware": {"ver": v}}
for subsys in ["input", "system", "battery"]:
    data[subsys] = {}
    for key in ["temp", "voltage", "current", "power"]:
        f = f"get_{subsys}_{key}"
        data[subsys][key] = getattr(pwr, f)()

for key in ["level", "health", "max_charge_level", "design_capacity"]:
    f = f"get_battery_{key}"
    data["battery"][key] = getattr(pwr, f)()

data["fan"] = {}
data["fan"]["speed"] = pwr.get_fan_speed()
data["fan"]["health"] = pwr.get_fan_health()

print(json.dumps(data))
