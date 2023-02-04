#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "STOP! Update the k3s install to set a --data-dir on the attached hhard drive first (see [here](https://docs.k3s.io/reference/server-config)), otherwise you'll regret how full your SD card gets!"
exit 1


# https://unix.stackexchange.com/a/146341
export DEBIAN_FRONTEND=noninteractive

echo "Enter hostname"
read hostname

apt upgrade -y
apt-get update -y
apt-get upgrade -y

####
# Shell customization, dotfile personalization
####
apt-get install -y zsh
usermod --shell /bin/zsh pi
echo "TODO - make a public dotfiles repo that can be curled without auth"

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

raspi-config nonint do_expand_rootfs
raspi-config nonint do_change_locale en_US.UTF-8
raspi-config nonint do_wifi_country US
raspi-config nonint do_hostname "$hostname"

###
# Install ssh keys...
###
(umask 077 && test -d /home/pi/.ssh || mkdir /home/pi/.ssh)
(umask 177 && touch /home/pi/.ssh/authorized_keys)
chown pi:pi /home/pi/.ssh
chown pi:pi /home/pi/.ssh/authorized_keys
curl --silent https://github.com/scubbo.keys >> /home/pi/.ssh/authorized_keys
echo "Finished updating ssh authorized_keys"

###
# ...and create your own
####
ssh-keygen -t ed25519 -N "" -C "scubbojj@gmail.com" -f /home/pi/.ssh/id_ed25519
chown pi:pi /home/pi/.ssh/id_ed25519
echo "Add this as a trusted key in Github and anywhere else that is appropriate:"
cat /home/pi/.ssh/id_ed25519.pub

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
