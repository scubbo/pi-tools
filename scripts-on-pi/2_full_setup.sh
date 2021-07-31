#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

while getopts h: flag
do
    case "${flag}" in
        h) hostname=${OPTARG};;
    esac
done

if [ -z "$hostname" ]; then
  echo "Hostname not set"
  exit 1
fi

####
# Change Hostname
# https://www.howtogeek.com/167195/how-to-change-your-raspberry-pi-or-other-linux-devices-hostname/
####

echo "Setting hostname to $hostname"
perl -i'' -pe "s/raspberrypi/$hostname/" /etc/hosts
echo $hostname > /etc/hostname

####
# Install Bonjour
# https://www.howtogeek.com/167190/how-and-why-to-assign-the-.local-domain-to-your-raspberry-pi/
####
apt-get install avahi-daemon

####
# Install Docker
# https://phoenixnap.com/kb/docker-on-raspberry-pi
####
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh
usermod -aG docker pi
# This permission-change might not take effect until the session
# restarts - you may need to reconnect a new ssh session.

####
# Install pip (prerequisite for docker-compose)
####
apt-get install -y python3-distutils python3-apt python3-pip
# curl -s https://bootstrap.pypa.io/get-pip.py | python3

####
# Install docker-compose
# https://dev.to/elalemanyo/how-to-install-docker-and-docker-compose-on-raspberry-pi-1mo
####
apt-get install libffi-dev libssl-dev
apt install python3-dev
pip3 install docker-compose
# Note - still not part of $PATH. Update to bashrc?

####
# Set docker containers to auto-restart
# https://dev.to/elalemanyo/how-to-install-docker-and-docker-compose-on-raspberry-pi-1mo
####
sudo systemctl enable docker

####
# Mount BERTHA
####
yes | apt install exfat-fuse
sudo mkdir /mnt/BERTHA
berthaDev=$(blkid | grep 'BERTHAIII' | perl -pe 's/(.*):.*/$1/')
berthaUUID=$(blkid | grep 'BERTHAIII' | perl -pe 's/.* UUID="(.*?)".*/$1/')
echo "UUID=$berthaUUID /mnt/BERTHA exfat defaults,auto,users,rw,nofail,umask=000 0 0" >> /etc/fstab
mount -a

####
# Install jellyfin
####
docker pull jellyfin/jellyfin

# TODO: Pull RC files
# If you install Plex again, consider docker version:
# https://github.com/plexinc/pms-docker
