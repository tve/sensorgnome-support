#! /bin/bash -e
# Configure and baby-sit cellular modem using mmcli (ModemManager)

[[ "$1" == "-r" ]] && reconfigure=1  # reconfigure unconditionally

echo
echo -n '===== check-modem '
date

config=$(cat /etc/sensorgnome/cellular.json) || true
apn=$(jq -r .apn <<<$config)
iptype=$(jq -r '.["ip-type"]' <<<$config)
[[ -z $iptype ]] && iptype=ipv4v6

# we could iterate through all modems, but for now we only do the last (see last() in jq expr)
eval $(mmcli -L -J | jq -j '.["modem-list"] | last | "modem=\(@sh)"')
echo Modem: $modem

if [[ -n "$modem" ]] && [[ -z "$apn" ]]; then
    # Pre-configured APNs...
    sim=$(mmcli -J -m $modem | jq -r .modem.generic.sim)
    iccid=$(mmcli -m $modem -i $sim -K | grep 'iccid' | sed -e 's/.*: *//')
    if [[ $iccid == 8988307* ]] || [[ $iccid == 8988323* ]]; then
        apn=super
    fi    
fi
echo "APN: $apn, IP type: $iptype"

count=0 # iteration count, if > 0 we're reconnecting
while [[ -n "$modem" ]]; do
    m=$(basename $modem)
    count=$((count+1))
    if (( $count > 1 )); then
        [[ -n "$reconfigure" ]] && exit 0
        (( $count > 5 )) && exit 1  # we'll come back in a few minutes...
        sleep 5
        eval $(mmcli -L -J | jq -j '.["modem-list"] | last | "modem=\(@sh)"')
        m=$(basename $modem)
    fi

    # Check if the modem is connected
    info=$(mmcli -J -m $m)
    state=$(jq -r .modem.generic.state <<<$info)
    echo "Modem state: $state"
    if [[ "$state" != "connected" ]]; then
        echo Not connected, reason: $(jq -r '.modem.generic["state-failed-reason"]' <<<$info)
        echo "Connecting modem $m, apn=$apn ip-type=$iptype"
        mmcli -m $m --simple-connect="apn=$apn,ip-type=$iptype"
        continue
    fi

    # Check that we have the correct APN
    bearer=$(jq -r '.modem.generic.bearers[0]' <<<$info)  # bearers[0] is the latest, phew...
    binfo=$(mmcli -J -m $m -b $bearer)
    cur_apn=$(jq -r .bearer.properties.apn <<<$binfo)
    echo "APN: $cur_apn"
    if [[ "$cur_apn" != "$apn" ]]; then
        echo "Configured APN is $apn, reconnecting modem"
        mmcli -m $m --simple-connect="apn=$apn,ip-type=$iptype"
        continue
    fi

    # Check that we have a default route
    defrt=$(ip route show default)
    iface=$(jq -r .bearer.status.interface <<<$binfo)
    echo "Interface: $iface"
    if ! grep -e "$iface" <<<$defrt; then
        if (( $count == 1 )); then
            echo "No default route via $iface, resetting modem"
            mmcli -m $m --reset
        else
            echo "No default route via $iface, waiting..."
        fi
        continue
    fi

    # If we're *the* default route, check that we have traffic in the past 90 minutes
    vnstat=$(vnstat -i $iface --json f 18)
    rx=$(jq -c '.interfaces[0].traffic.fiveminute | map(.rx) | add' <<<$vnstat)
    echo "RX bytes in last 90 minutes: $rx"
    if [[ $(ip route get 1.1.1.1) =~ $iface ]]; then
        echo "Default route uses $iface"
        if (( $rx < 10240 )); then
            echo "No traffic in last 90 minutes, resetting modem"
            mmcli -m $m --reset
            continue
        fi
    else
        echo "Default route is not via $iface"
    fi

    echo "Modem $m is OK"
    exit 0

done
