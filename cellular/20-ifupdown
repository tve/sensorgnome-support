#! /bin/bash

[ $# -lt 4 ] && exit 1

MODEM_PATH="$1"
BEARER_PATH="$2"
INTERFACE="$3"
STATE="$4"

MODEM_ID=$(basename ${MODEM_PATH})
BEARER_ID=$(basename ${BEARER_PATH})

if [[ "$STATE" == "connected" ]]; then
    ip link set dev $INTERFACE up
    logger -t "modemmanager" "if-up for modem ${MODEM_ID} interface ${INTERFACE}"
elif [[ "$STATE" == "disconnected" ]]; then
    ip link set dev $INTERFACE down
    logger -t "modemmanager" "if-down for modem ${MODEM_ID} interface ${INTERFACE}"
else
    logger -t "modemmanager" "unknown state: '$STATE' for modem ${MODEM_ID}, interface ${INTERFACE}"
fi
