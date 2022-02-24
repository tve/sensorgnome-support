#! /bin/bash -e
# Upgrade the SG software using apt. Expects a list of packages as arguments. If passed a
# -s flag will also upgrade system packages.

if [[ "$#" == 0 ]]; then
    echo "Usage: $0 <package1> <package2> ..."
    echo "or     $0 -s  # upgrade all packages"
    exit 1
fi

if [[ "$1" == -s ]]; then packages=""
else packages="$@"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get -y upgrade "$packages"
