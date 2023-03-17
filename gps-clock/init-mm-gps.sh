#! /bin/bash
# Initialize any GPS found by ModemManager, e.g. that is part of a cellular modem

RE='^(.+.\s+)?/org/freedesktop/ModemManager./Modem/([0-9]+) '

mmcli -M | while read line; do
    echo "line=$line"
    if ! [[ $line =~ $RE ]]; then continue; fi
    modem=${BASH_REMATCH[2]}
    echo "New modem $modem"
    if ! mmcli -m $modem --enable; then
        echo "Failed to enable modem $modem"
        continue
    fi
    loc=$(mmcli -m $modem -K --location-status)
    if ! grep -q 'location.capabilities.*gps-unmanaged' <<< $loc; then
        echo "Modem $modem does not support GPS or is missing SIM"
        continue
    fi
    if grep -q 'location.enabled.*gps-unmanaged' <<< $loc; then
        echo "Modem $modem already has GPS enabled"
    else
        echo "Enabling gps-unmanaged for modem $modem"
        mmcli -m $modem --location-enable-gps-unmanaged
    fi
    # symlink /dev/ttyGPS to the appropriate port
    port=$(mmcli -m $modem -K | awk '/ports.value.*:.*\(gps\)/{print $3}')
    echo "Symlinking /dev/ttyGPS to /dev/$port"
    rm -f /dev/ttyGPS
    ln -sf /dev/$port /dev/ttyGPS
done
