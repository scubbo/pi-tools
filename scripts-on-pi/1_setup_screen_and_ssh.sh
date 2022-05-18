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
apt-get -y upgrade

####
# Install screen
####
apt-get install -y screen

###
# Install ssh keys...
###
(umask 077 && test -d /home/pi/.ssh || mkdir /home/pi/.ssh)
(umask 177 && touch /home/pi/.ssh/authorized_keys)
chown pi /home/pi/.ssh/authorized_keys
chgrp pi /home/pi/.ssh/authorized_keys
curl --silent https://github.com/scubbo.keys >> /home/pi/.ssh/authorized_keys
echo "Finished updating ssh authorized_keys"

###
# Remove ability to authenticate with password
###
echo "Removing ability to authenticate with password. Keep another ssh connection to this host live just in case you need to interrupt anything"
echo "Press any key to continue"
read -n 1 a
echo "Not yet automated - do the instructions from here:"
echo "https://www.cyberciti.biz/faq/how-to-disable-ssh-password-login-on-linux/"

