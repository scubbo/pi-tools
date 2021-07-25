#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

####
# Apt updates
####
apt-get update
yes | apt-get upgrade

####
# Install screen
####
apt-get install screen