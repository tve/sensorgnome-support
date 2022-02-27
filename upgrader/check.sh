#! /bin/bash -e

date
apt-get update
apt list --upgradeable 2>/dev/null
