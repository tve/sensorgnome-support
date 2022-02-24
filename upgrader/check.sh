#! /bin/bash -e

apt-get update
apt list --upgradeable 2>/dev/null
