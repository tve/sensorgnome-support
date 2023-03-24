#! /bin/bash
# One-time installation of modem-manager if not already installed

# Set-up bullseye backports (we need modemmanager from there specifically)
# apt only installs packages from this repo if -t bullseye-backports is specified
if ! [[ -f /etc/apt/sources.list.d/bullseye-backports.list ]]; then
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138 0E98404D386FA1D9
    echo 'deb http://deb.debian.org/debian/ bullseye-backports main' | \
        sudo tee /etc/apt/sources.list.d/bullseye-backports.list
    apt-get update
    apt-get -o Dpkg::Options::="--force-confold" install -y sensorgnome
    apt-get install -y -t bullseye-backports modemmanager
    echo "Upgraded ModemManager"
fi
