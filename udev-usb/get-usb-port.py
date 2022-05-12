#! /usr/bin/python3
# Output the port number of a USB device given its sysfs device path
import sys
import re
import subprocess

PORT_MAP_FILE = "/etc/sensorgnome/usb-port-map.txt"

path = sys.argv[1]
# The path should have a section that has the USB path, which should be of the form:
# /bus-port.port.port.port:configuration.interface
# where the port.port section is the path through hubs
# Ex: 1-1.1.2.3:1.1 (bus 1, ports 1, 1, 2, 3, configuration 1, interface 1)
# http://gajjarpremal.blogspot.com/2015/04/sysfs-structures-for-linux-usb.html
# rtlsdr devices don't end up with a :config.intf part and the venId:devId in the detection, so
# we also have to support that
m = re.search(r'/\d-((\d+\.)*\d+)($|:[\d.]+/)', path)
if not m:
    sys.stderr.write(f"Error: {path} is not a valid path\n")
    sys.exit(1)
#print(f"match={m[1]}")
port_path = m[1]
print(f"PORT_PATH={port_path.replace('.', '_')}")

# read port mapping file and apply any mapping found
try:
    with open(PORT_MAP_FILE, 'r') as file:
        for line in file:
            l = re.search(r'^\s*([\d.]+)\s*->\s*(\d+)', line)
            if l and l[1] == port_path:
                print(f"PORT_NUM={l[2]}")
                sys.stderr.write(f"USB path {port_path} -> port {l[2]}\n")
                sys.exit(0)
except OSError:
    sys.stderr.write(f"No port map file found at {PORT_MAP_FILE}")

# no explicit mapping, apply default one
m = list(map(int, m[1].split('.')))
# the first digit is the root hub, on rPi or so there's just one and we turn
# that into a 0 initial value. But in case there's another root hub on some system
# we add 100.
port = (m[0]-1)*100
if len(m) == 1:
    # device plugged into root hub, e.g. directly into rPi Zero micro-USB: first digit is port number
    port += m[0]
elif len(m) == 2:
    # device plugged into port on internal hub: second digit is port number
    port += m[1]
elif len(m) == 3:
    # device plugged into a hub: second digit is port of root hub, third digit is port of hub
    port += m[1]*10 + m[2]-1
elif len(m) == 4:
    # device plugged into a daisy-chained hub (chaining may be internal to a 7-port hub),
    # second digit is port of root hub, third digit is port of hub, fourth digit is port of
    # daisy-chained hub. We hack the numbering and count the daisy-chained hub ports down from
    # 10. Ex: two 4-port hubs daisy-chained on root hub port 2 with the second hub in port 3
    # of hte first hub. We end up with numbers 20, 21, 23 for devices in the three remaining first
    # hub ports, and numbers 29, 28, 27, 26 in the daisy chained hub.
    port += m[1]*10 + 10 - m[3]
else:
    sys.stderr.write("Error: cannot parse path %s\n" % m)
    sys.exit(1)
print(f"PORT_NUM={port}")
sys.stderr.write(f"USB path {port_path} -> port {port}\n")
