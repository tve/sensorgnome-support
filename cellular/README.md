Cellular Modem support
======================

Support cellular modems with QMI or ECM mode using ModemManager.
This should support any modem that ModemManager supports.
The main functionality implemented here is:

- Configure the modem according to /etc/sensorgnome/cellular.json
- Baby-sit the modem so it stays connected

In addition, sg-control queries mmcli directly to display the current modem status.

## Notes

- QMI vs. ECM: https://www.jeffgeerling.com/blog/2022/using-4g-lte-wireless-modems-on-raspberry-pi
  Bottom line is that in ECM mode the cell modem acts as a router with NAT while in
  QMI mode the host gets direct cell IP address and connection.

- On LTE links there is no DHCP server on the network, IP information is provided during connection
  setup, statically through LTE protocol.
  DHCP server you connect to is specific to QMI (if you switch modem into MBIM mode there will be
  no DHCP server any more), and located on the modem, it is serving this static IP to the client.

