#! /bin/bash -e

# start with a simple apt update
date
apt-get update

# Hacky hook to allow us to tweak things before apt actually performs any upgrade, specifically,
# we upgrade the upgrader package as part of the check, this allows the post-install script to
# change the apt configuration in order to add/change a repository. A second
# apt-get update then picks up those changes and the SG is ready for the real upgrade. Phew.
#
# The alternative to this sneaky upgrade of the upgrader would be to download a "do-the-upgrade"
# script and run that, but then we'd have to start matching versions of that script with what
# is actually going to be installed, with major headaches if one wants to upgrade/downgrade to
# a specific version which is not the latest.
if apt list --upgradeable sg-upgrader 2>/dev/null | grep -q upgradable; then
    echo '** Upgrading upgrader package'
    export DEBIAN_FRONTEND=noninteractive
    rm -f /run/double-update
    apt-get -y -o Dpkg::Options::="--force-confold" install sg-upgrader
    if [[ -f /run/double-update ]]; then
        echo '** Re-running apt-get update'
        apt-get update
        rm -f /run/double-update
    fi
fi

apt list --upgradeable 2>/dev/null
echo "_END_"
