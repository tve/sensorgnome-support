#! /bin/bash -ex
# Create a data partition to fill the SDcard if it doesn't exist yet

DATA_PART="$(findmnt /data -o source -n || true)"
if [[ -n "$DATA_PART" ]]; then
  echo "Data partition exists"
  exit 0
fi

ROOT_PART=$(findmnt / -o source -n)
ROOT_DEV="/dev/$(lsblk -no pkname $ROOT_PART)"
FREE_SIZE=$(parted -ms $ROOT_DEV unit b print free | tail -n 1 | grep free | cut -f 4 -d: | sed -e 's/B//')
if [[ -z "$FREE_SIZE" ]]; then
  echo "No free space for data partition"
  exit 1
fi
if [[ "$FREE_SIZE" -lt 1073741824 ]]; then
  echo "Less than 1GB free space for data partition, OOPS"
  exit 1
fi

FREE_START=$(parted "$ROOT_DEV" -ms unit s print free | tail -n 1 | cut -f 2 -d:)
FREE_END=$(parted "$ROOT_DEV" -ms unit s print free | tail -n 1 | cut -f 3 -d:)
echo "Creating data partition starting at sector $FREE_START and ending $FREE_END"
parted -ms -a none $ROOT_DEV unit s mkpart primary fat32 $FREE_START $FREE_END
parted -ms $ROOT_DEV p

# create filesystem
DATA_PART="/dev/$(lsblk -nl -o NAME | tail -n 1)"
echo "Creating FAT32 filesystem in $DATA_PART"
mkfs.fat -n DATA $DATA_PART

# mount and move /data stuff in rootfs over
echo "Moving data from rootfs /data to new partition"
mount $DATA_PART /mnt
mkdir -p /data
date >/data/created
mv /data/* /mnt
umount /mnt
mount $DATA_PART /data
mkdir -p /data/config /data/SGdata
df -h

# create fstab entry
if ! grep -q /data /etc/fstab; then
  ROOT_ENTRY=$(grep '\s/\s' /etc/fstab)
  DATA_NUM=$(parted "$ROOT_DEV" -ms print | tail -n 1 | cut -f 1 -d:)
  DATA_UUID=$(echo $ROOT_ENTRY | sed -e "s/[0-9]\s.*/$DATA_NUM/")
  echo "$DATA_UUID /data vfat defaults,noatime 0" >>/etc/fstab
  echo ""
  echo "fstab:"
  cat /etc/fstab
fi
