#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

####
# Mount NAS
####
mkdir /mnt/NAS
chown pi:pi /mnt/NAS
echo -e "rassigma.avril:/mnt/BERTHA\t/mnt/NAS\tnfs\tdefaults\t0\t0" >> /etc/fstab

####
# Set up fail2ban
####
ln -s /mnt/NAS/etc/fail2ban/jail.local /etc/fail2ban/jail.local
service fail2ban restart