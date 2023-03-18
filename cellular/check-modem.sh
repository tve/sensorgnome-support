#! /bin/bash
# Configure and baby-sit cellular modem using mmcli (ModemManager)

[[ "$1" == "-r" ]] && reconfigure=1  # reconfigure unconditionally

if [[ -f /etc/sensorgnome/cellular.json ]]; then
    config=$(cat /etc/sensorgnome/cellular.json)
else
    echo '{"apn":"","ip-type":"ipv4v6"}' >/etc/sensorgnome/cellular.json
    config=""
fi
apn=$(jq -r .apn <<<$config)
iptype=$(jq -r '.["ip-type"]' <<<$config)
[[ -z $iptype ]] && iptype=ipv4v6

# we could iterate through all modems, but for now we only do the last (see last() in jq expr)
eval $(mmcli -L -J | jq -j '.["modem-list"] | last | "modem=\(@sh)"')
if [[ -z "$modem" ]]; then
    echo "No modem found"
    exit 0
fi

# handle APN auto-detection for some SIM cards
if [[ -n "$modem" ]] && [[ -z "$apn" ]]; then
    # Pre-configured APNs...
    sim=$(mmcli -J -m $modem | jq -r .modem.generic.sim)
    iccid=$(mmcli -m $modem -i $sim -K | grep 'iccid' | sed -e 's/.*: *//')
    # Twilio / sixfab "super SIM"
    if [[ $iccid == 8988307* ]] || [[ $iccid == 8988323* ]]; then
        echo "Twilio super SIM detected, using APN=super"
        apn=super
        iptype=ipv4v6
        echo '{"apn":"super","ip-type":"ipv4v6"}' >/etc/sensorgnome/cellular.json
    fi    
fi

count=0 # iteration count, if > 0 we're reconnecting
while [[ -n "$modem" ]]; do
    m=$(basename $modem)
    count=$((count+1))
    if (( $count > 1 )); then
        [[ -n "$reconfigure" ]] && exit 0  # don't loop if we're reconfiguring
        (( $count > 5 )) && exit 1  # we'll come back in a few minutes...
        sleep 5
        eval $(mmcli -L -J | jq -j '.["modem-list"] | last | "modem=\(@sh)"')
        m=$(basename $modem)
    fi

    # Check if the modem is connected
    info=$(mmcli -J -m $m)
    state=$(jq -r .modem.generic.state <<<$info)
    echo "Modem: $modem, state: $state, APN: $apn, IP type: $iptype"
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
    if [[ "$cur_apn" != "$apn" ]]; then
        echo "Configured APN is $apn, reconnecting modem"
        mmcli -m $m --simple-connect="apn=$apn,ip-type=$iptype"
        continue
    fi

    # Check that we have a default route
    defrt=$(ip route show default)
    iface=$(jq -r .bearer.status.interface <<<$binfo)
    if [[ "$iface" == ttyUSB* ]]; then
        net=$(jq -r '.modem.generic.ports | last | sub(" .*"; "")' <<<$info)
        echo "Interface $iface -> $net"
        iface=$net
    fi
    if ! grep -e "$iface" <<<$defrt; then
        if (( $count == 1 )); then
            echo "No default route via $iface, resetting modem"
            mmcli -m $m --reset
            sleep 20
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
            exit 1
        fi
    else
        echo "System default route is not via $iface"
    fi

    #echo "Modem $m is OK"
    exit 0

done
