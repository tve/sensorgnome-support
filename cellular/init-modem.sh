#! /bin/bash
# Watch ModemManager for new modems and connect modem

RE='^(.+.\s+)?/org/freedesktop/ModemManager./Modem/([0-9]+) '

mmcli -M | while read line; do
    echo "line=$line"
    if ! [[ $line =~ $RE ]]; then continue; fi
    if [[ ${BASH_REMATCH[1]} == *-* ]]; then continue; fi # modem disabled
    modem=${BASH_REMATCH[2]}
    echo "New modem $modem, configuring..."
    ./check-modem.sh &
done
