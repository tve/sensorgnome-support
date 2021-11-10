#! /usr/bin/python3

import re
import json
import subprocess
from pathlib import Path

def camel_to_snake(str):
    return re.sub('(.)([A-Z][a-z]+)', r'\1_\2', str).lower()

# list all files in /dev/sensorgnome
dev_list = [ str(p.name) for p in Path("/dev/sensorgnome").iterdir() if "port=" in str(p) ]
out = {}
for dev in dev_list:
    try:
        parts = dev.split(".")
        name = parts.pop(0)
        attr = { camel_to_snake(p[0]) : p[1] for p in [ p.split("=") for p in parts] }
        attr["name"] = name
        attr["type"] = name
        port = attr["port"]
        out[port] = attr
        if re.match(r'funcube.*', name):
            out[port]["type"] = "fcd"
            proc = subprocess.run(f"fcd -p {attr['usb_path']} -g", capture_output=True, shell=True)
            try:
                freq = int(proc.stdout.decode("utf-8").strip())
                out[port]["frequency"] = f"{freq/1000000.0}Mhz"
            except:
                out[port]["frequency"] = "?"
        elif re.match(r'rtlsdr.*', name):
            out[port]["frequency"] = "?"
        elif re.match(r'usbAudio', name):
            out[port]["type"] = name
            with open(f"/proc/asound/card{attr['alsa_dev']}/stream0", "r") as f:
                for line in f:
                    m = re.search(r'(.*) at usb-musb')
                    if m:
                        out[port]["name"] = m[0]
        elif re.match(r'CornellTagXCVR', name):
            out[port]["name"] = "CTT 434MHz Rcvr"
        elif re.match(r'disk', name):
            pass
        elif re.match(r'gps', name):
            if attr['kind'] == "hat":
                out[port]["name"] = "Adafruit GPS hat with PPS"
            elif attr['kind'] == "cape":
                out[port]["name"] = "Compudata/Adafruit GPS cape with PPS"
            else:
                out[port]["name"] = "USB GPS receiver" + (" with PPS" if "pps" in attr else "")
    except:
        pass

# add some stuff about the system
#proc = subprocess.run("uname -a", capture_output=True, shell=True)

print(json.dumps(out, indent=4))
