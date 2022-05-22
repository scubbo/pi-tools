#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "Enter hostname"
read hostname

apt upgrade -y

raspi-config nonint do_expand_rootfs
raspi-config nonint do_change_locale en_US.UTF-8
raspi-config nonint do_wifi_country US
raspi-config nonint do_hostname
apt-get install -y git

# TODO - key creation. Awkward because we're currently acting as root,
# but we'd want them to be created under pi's home.
# I'm sure you can do something like that with `su`

# https://anthonynsimon.com/blog/kubernetes-cluster-raspberry-pi/
# Uses Ubuntu rather than Raspbian, but should work the same? Hopefully!
apt install -y docker.io

####
# Set permissions for docker
####
groupadd -f docker
usermod -aG docker pi

####
# Install screen
####
apt-get install -y screen

####
# Install fail2ban
# (configuration and initialization happen in per-role setup)
####
apt install -y fail2ban

###
# Install ssh keys
###
(umask 077 && test -d /home/pi/.ssh || mkdir /home/pi/.ssh)
(umask 177 && touch /home/pi/.ssh/authorized_keys)
chown pi /home/pi/.ssh/authorized_keys
chgrp pi /home/pi/.ssh/authorized_keys
curl --silent https://github.com/scubbo.keys >> /home/pi/.ssh/authorized_keys
echo "Finished updating ssh authorized_keys"

# Slightly different cmdline.txt options - ref
# https://github.com/me-box/databox/issues/303
#
# Original cmdline.txt:
# `console=serial0,115200 console=tty1 root=PARTUUID=<id> rootfstype=ext4 fsck.repair=yes rootwait`
#
sed -i \
'$ s/$/ cgroup_enable=memory cgroup_memory=1 swapaccount=1/' \
/boot/cmdline.txt
echo "The preceding change necessitates a reboot. Going down in..."
for i in {10..1}
do
   echo $i
   sleep 1
done
reboot now
