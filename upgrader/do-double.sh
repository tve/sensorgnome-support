#! /bin/bash -ex
# One-time hack to perform a double upgrade when going
# from pre 2023-080 to later versions
# wait for install to finish
echo "Waiting to perform double update"
while pgrep -x 'dpkg|apt|apt-get' > /dev/null; do sleep 1; done
export DEBIAN_FRONTEND=noninteractive
# make sure no one else is locking the dpkg database
echo "Starting double update"
flock --exclusive --close /var/lib/dpkg/lock -c \
  'apt-get update; apt-get install -y -o Dpkg::Options::="--force-confold" sensorgnome'
touch /opt/sensorgnome/upgrader/has-double
