#! /bin/bash
# Configure and baby-sit cellular modem using mmcli (ModemManager)
# Expects to be run periodically, e.g. on a timer, but not too frequently, e.g. every 5 minutes
# at the shortest. If it does something it loops a few times to check the outcome and nudge
# things forward. Passing -r does only one pass and is used when the UI reconfighures the
# modem to avoid having multiple instances of this script running at the same time.
# If the configuration looks correct check-modem.sh will exit without doing anything.
# Not implemented: If -p is passed, it will actually ping 1.1.1.1 to check connectivity and reset the modem if
# it doesn't work. This is used by the uploading apps when they find that they don't have
# connectivity.

[[ "$1" == "-r" ]] && reconfigure=1  # reconfiguring

if [[ -f /etc/sensorgnome/cellular.json ]]; then
    config=$(cat /etc/sensorgnome/cellular.json)
else
    echo '{"apn":"changeme","ip-type":"ipv4v6","allow-roaming":"yes"}' >/etc/sensorgnome/cellular.json
    config=""
fi
apn=$(jq -r .apn <<<$config)
iptype=$(jq -r '.["ip-type"]' <<<$config)
roaming=$(jq -r '.["allow-roaming"]' <<<$config)
[[ -z $iptype ]] && iptype=ipv4v6

# we could iterate through all modems, but for now we only do the last (see last() in jq expr)
eval $(mmcli -L -J | jq -j '.["modem-list"] | last | "modem=\(@sh)"')
if [[ "$modem" == null ]]; then
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
        roaming=yes
        echo '{"apn":"super","ip-type":"ipv4v6","allow-roaming":"yes"}' >/etc/sensorgnome/cellular.json
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
    info=$(mmcli -J -m $m)
    bearer=$(jq -r '.modem.generic.bearers[0]' <<<$info)  # bearers[0] is the latest, phew...

    # Check if the modem is connected
    state=$(jq -r .modem.generic.state <<<$info)
    oper=$(jq -r '.modem."3gpp"."operator-code" + " " + .modem."3gpp"."operator-name"' <<<$info)
    echo "Modem ${modem##/}, state: $state, APN: $apn $iptype, Operator: $oper"
    if [[ "$state" != "connected" ]] || [[ "$bearer" == "null" ]]; then
        echo Not connected, reason: $(jq -r '.modem.generic["state-failed-reason"]' <<<$info)
        if [[ "$bearer" == null ]]; then
            #echo Disconnecting existing bearer
            mmcli -m $m --simple-disconnect
            sleep 2
        fi
        #echo "Configuring initial EPS bearer settings"
        mmcli -m $m --3gpp-set-initial-eps-bearer-settings="apn=$apn,ip-type=$iptype,allow-roaming=$roaming"
        sleep 2
        echo "Connecting modem $m, apn=$apn ip-type=$iptype allow-roaming=$roaming"
        mmcli -m $m --simple-connect="apn=$apn,ip-type=$iptype,allow-roaming=$roaming"
        continue
    fi

    # Check that we have the correct APN
    binfo=$(mmcli -J -m $m -b $bearer)
    cur_apn=$(jq -r .bearer.properties.apn <<<$binfo)
    if [[ "$cur_apn" != "$apn" ]]; then
        echo "Configured APN is $apn, disconnecting bearer"
        mmcli -m $m --simple-disconnect
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
    rx=$(jq -c '.interfaces[0].traffic.fiveminute | map(.rx) | add' <<<$vnstat) || \
        echo "Error getting RX bytes from vnstat: $vnstat"
    echo "RX bytes in last 90 minutes: $rx"
    dr=$(ip route get 1.1.1.1)
    if [[ "$dr" = *${iface}* ]]; then
        echo "Default route uses $iface"
        if (( $rx < 10240 )); then
            echo "No traffic in last 90 minutes, pinging 1.1.1.1"
            if ping -n -c 20 -I $iface 1.1.1.1 | grep -q ' 0 received'; then
                echo "Resetting modem"
                mmcli -m $m --reset
                exit 1
            else
                echo "Ping OK"
            fi
        fi
    else
        dr=$(echo $dr | sed -e 's/.*dev \([^ ]*\).*/\1/')
        echo "System default route is via $dr, not $iface (OK)"
    fi

    #echo "Modem $m is OK"
    exit 0

done
