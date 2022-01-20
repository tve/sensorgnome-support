#! /bin/bash -e
#
# register this SG, telling sensorgnome.org we exist and obtaining a
# port tunnel number and pub/priv keypair.
# Exits with 0 if registration is successful and with 1 if not
#
# Expects two commandline arguments: dot_ssh_dir and Sensorgnome_ID

if [[ "${#*}" != 2 ]]; then
  echo Usage: $0 dot_ssh_dir sensorgnome_id
  exit 1
fi
SSH="$1"
SGID=$2

UNIQUE_KEY_FILE="$SSH/${SGID}_id_dsa"
UNIQUE_KEY_FILE_PUB="$UNIQUE_KEY_FILE.pub"

if [[ ! -f "$UNIQUE_KEY_FILE" ]]; then
  echo "Fetch keypair for $SGID"
  FACTORY_KEY_FILE="$SSH/id_dsa_factory"
  TUNNEL_PORT_FILE="$SSH/tunnel_port"
  AUTHORIZED_KEYS_FILE="$SSH/authorized_keys"

  #SG_USER_ID = 1000
  #SG_USER_GROUP = 1000

  UPLOAD_USER=sg_remote
  UPLOAD_HOST=sensorgnome.org
  UPLOAD_PORT=59022

  # quit if already registered
  # TvE: re-registering at every boot in case sensorgnome_id changes...
  #if [[ -f UNIQUE_KEY_FILE ]]; then
  #    exit (0)
  #fi

  REG="$(echo $SGID | /usr/bin/ssh -T \
      -i $FACTORY_KEY_FILE \
      -o StrictHostKeyChecking=accept-new \
      -p $UPLOAD_PORT \
      $UPLOAD_USER@$UPLOAD_HOST)"
  [[ $? != 0 ]] && exit 1
  if [[ $(wc -l <<<"$REG") -le 3 ]]; then
    echo "Unknown response from sensorgnome.org:"
    echo "$REG"
    exit 2
  fi
  echo "Got keypair response"

  # save the tunnel port number
  head -1 <<<"$REG" >$TUNNEL_PORT_FILE

  # save the public key
  head -2 <<<"$REG" | tail -1 >$UNIQUE_KEY_FILE_PUB
  chmod 600 $UNIQUE_KEY_FILE_PUB

  # append public key to the authorized_keys file
  if ! grep -q "$(cat $UNIQUE_KEY_FILE_PUB)" $AUTHORIZED_KEYS_FILE; then
    cat $UNIQUE_KEY_FILE_PUB >>$AUTHORIZED_KEYS_FILE
  fi
  chmod 600 $AUTHORIZED_KEYS_FILE

  # save the private key
  tail -n +3 <<<"$REG" >$UNIQUE_KEY_FILE
  chmod 600 $UNIQUE_KEY_FILE
  echo "Keypair saved"
else
  echo "Found existing registration keypair"
fi

# Link "std" key file to SGID version
ln -sf $UNIQUE_KEY_FILE $SSH/id_dsa
ln -sf $UNIQUE_KEY_FILE_PUB $SSH/id_dsa.pub

exit 0 # success!
