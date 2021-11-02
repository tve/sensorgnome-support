#!/bin/bash
#
# open a tunnels to sensorgnome.org
#
# map server:TUNNEL_PORT -> localhost:22  (ssh reverse tunnel)
# map localhost:59024 -> server:59024     (message streaming)

# Expects the SSH directory with the keys as first argument
if [[ "${#*}" != 1 ]]; then
  echo Usage: $0 dot_ssh_dir
  exit 1
fi
SSH="$1"

TUNNEL_PORT_FILE=$SSH/tunnel_port
UNIQUE_KEY_FILE=$SSH/id_dsa
REMOTE_USER=sg_remote
REMOTE_HOST=sensorgnome.org
REMOTE_SSH_PORT=59022
REMOTE_STREAM_PORT=59024
LOCAL_STREAM_PORT=59024

LAST=$(date +%s)

while true; do
  if [[ -f $TUNNEL_PORT_FILE ]]; then
      read TUNNEL_PORT < $TUNNEL_PORT_FILE
      ssh -f -N -T \
          -L$LOCAL_STREAM_PORT:localhost:$REMOTE_STREAM_PORT \
          -R$TUNNEL_PORT:localhost:22 \
          -o ControlMaster=auto \
          -o ControlPath=/tmp/sgremote \
          -o ServerAliveInterval=25 \
          -o ServerAliveCountMax=5 \
          -i $UNIQUE_KEY_FILE \
          -p $REMOTE_SSH_PORT \
          $REMOTE_USER@$REMOTE_HOST
      # tunnel died, sleep some before restart
      NOW=$(date +%s)
      ALIVE=$(($NOW-$LAST))
      if [[ $ALIVE -gt 600 ]]; then
        # tunnel was alive for a reasonably long time, restart almost immediately
        echo "SSH died, was alive a long time, restarting in 10s"
        sleep 10
      else
        # tunnel basically just died again, sleep somewhat longer in order not to hit the failure
        # point so hard (and in case of cellular not to rack up charges)
        echo "SSH died, was alive only briefly, restarting in 5min"
        sleep 300
      fi
  else
      echo "Sleeping: $TUNNEL_PORT_FILE missing"
      sleep 60
  fi
done
