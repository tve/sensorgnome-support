#! /bin/bash -e
# Upgrade the SG software using apt. Expects a list of packages as arguments. If passed a
# -s flag will also upgrade system packages.

if [[ "$#" == 0 ]]; then
    echo "Usage: $0 <package1> <package2> ..."
    echo "or     $0 -s  # upgrade all packages"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
date
set -x

if [[ "$1" == -s ]]; then
    CMD="apt-get -y upgrade"
else
    CMD="apt-get -y install $packages"
fi

TERM=dumb systemd-run --scope --collect --description="sg-upgrade" $CMD
echo "Restarting sg-control (web server) in 10 seconds..."
sleep 10
systemctl restart sg-control.service
