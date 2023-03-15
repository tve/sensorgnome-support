#! /bin/bash

[ $# -lt 4 ] && exit 1

MODEM_PATH="$1"
BEARER_PATH="$2"
INTERFACE="$3"
STATE="$4"

MODEM_ID=$(basename ${MODEM_PATH})
BEARER_ID=$(basename ${BEARER_PATH})

logger -t "modemmanager" "modem ${MODEM_ID}, bearer ${BEARER_ID}, interface ${INTERFACE}: ${STATE}"
exit $?
