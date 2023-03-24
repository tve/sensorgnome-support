#! /bin/bash
# Initialize any GPS found by ModemManager, e.g. that is part of a cellular modem

RE='^(.+.\s+)?/org/freedesktop/ModemManager./Modem/([0-9]+) '

mmcli -M | while read line; do
    echo "line=$line"
    if ! [[ $line =~ $RE ]]; then continue; fi
    if [[ ${BASH_REMATCH[1]} == *-* ]]; then continue; fi # modem disabled
    modem=${BASH_REMATCH[2]}
    echo "New modem $modem, sleeping 10 seconds..."
    sleep 10
    if ! mmcli -m $modem --enable; then
        echo "Failed to enable modem $modem"
        continue
    fi
    loc=$(mmcli -m $modem -K --location-status)
    kind=
    grep -q 'location.capabilities.*gps-nmea' <<<$loc && kind=gps-nmea
    grep -q 'location.capabilities.*gps-unmanaged' <<<$loc && kind=gps-unmanaged
    if [[ -z "$kind" ]]; then
        echo "Modem $modem does not support GPS or is missing SIM: $loc"
        continue
    fi
    if grep -q "location.enabled.*$kind" <<< $loc; then
        echo "Modem $modem already has GPS enabled"
    else
        echo "Enabling $kind for modem $modem"
        mmcli -m $modem --location-enable-$kind
    fi
    # symlink /dev/ttyGPS to the appropriate port
    port=$(mmcli -m $modem -K | awk '/ports.value.*:.*\(gps\)/{print $3}')
    echo "Symlinking /dev/ttyGPS to /dev/$port"
    rm -f /dev/ttyGPS
    ln -sf /dev/$port /dev/ttyGPS
    systemctl restart gpsd
done
