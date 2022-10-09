SensorGnome Supervisor
======================

Monitoring data
---------------

Measurement interval: 1 minute ?
Reporting interval: 5 min std / 1 hr on cell ?

SYS: uptime, bootcount, 
CPU: 5min load avg, avg util
MEM: total, available
BOOT-FS, ROOT-FS, DATA-FS: total, used, bytes read/write
TIME: source, delay, ...
WIFI-AP: state, clients, bytes in/out
WIFI-STA: state, ssid, chan, security, rssi, addr, gw, bytes in/out
ETH: state, addr, gw, bytes in/out
CELL: state, signal, carrier, cell-id, addr, gw, bytes in/out
NET: dns, default-route
CADDY: state, mem, cpu, 20x/40x/50x count
SG-CTRL: state, mem, cpu, ??
USB: lsusb info??
POWER: volt, amps, watt
BATTERY: volt, amp, watt
GPS: state, fix

Logging
-------

- /var/log/syslog
- /var/log/sg-control.log

Commands
--------

- reboot
- restart service X
- systemctl status X
- send logs
- start/stop wifi-ap
- start/stop wifi-sta ??
- get file
- set file
- exec
