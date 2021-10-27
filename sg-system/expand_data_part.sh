#! /bin/bash
# Expand the data partition to fill the SDcard, it is initially created with a minimal size

DATA_PART="$(findmnt /data -o source -n)"
DATA_DEV="/dev/$(lsblk -no pkname "$DATA_PART")"
PART_NUM="$(echo "$DATA_PART" | grep -o "[[:digit:]]*$")"
# NOTE: the NOOBS partition layout confuses parted. For now, let's only 
# agree to work with a sufficiently simple partition layout
if [ "$PART_NUM" -ne 2 ]; then
  echo "Your partition layout is not currently supported by this tool. You are probably using NOOBS, in which case your root filesystem is already expanded anyway."
  exit 1
fi
LAST_PART_NUM=$(parted "$DATA_DEV" -ms unit s p | tail -n 1 | cut -f 1 -d:)
if [ $LAST_PART_NUM -ne $PART_NUM ]; then
  echo "$DATA_PART is not the last partition. Don't know how to expand"
  exit 1
fi
# Get the starting offset of the root partition
PART_START=$(parted "$DATA_DEV" -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')
[ "$PART_START" ] || exit 1
# Return value will likely be error for fdisk as it fails to reload the
# partition table because the root fs is mounted
fdisk "$DATA_DEV" <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START
p
w
EOF

# now set up an init.d script
cat <<EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO
. /lib/lsb/init-functions
case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs "$ROOT_PART" &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF
  chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Root partition has been resized.\nThe filesystem will be enlarged upon the next reboot" 20 60 2
  fi
}

echo reboot
