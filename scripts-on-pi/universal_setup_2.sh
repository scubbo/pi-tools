#!/bin/bash

# For utilities that should exist on all nodes, but aren't fundamental enough to belong in the 1st setup script

# No `set -x` here, as that would get noisy!
set -euo pipefail

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

####
# Set up dotfiles
####
CODE_DIR=/home/pi/Code
mkdir -p $CODE_DIR
chown pi:pi $CODE_DIR
cd $CODE_DIR
GIT_SSH_COMMAND='ssh -i /home/pi/.ssh/id_ed25519 -o StrictHostKeyChecking=no' git clone git@github.com:scubbo/dotfiles.git
su -c $CODE_DIR/dotfiles/setup.sh pi
