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

####
# Trust self-signed certificate for Docker Registry
####
SHARED_CERT_DIR="/usr/local/share/ca-certificates"
mkdir -p $SHARED_CERT_DIR
# Must be a cp, not a ln, since this will be accessed by containers (e.g. Drone)
# which won't be able to access the base file
#
# Note that `.crt` is required in order to be picked up by the following command!
cp /mnt/NAS/certs/live/docker-registry.scubbo.org/cert.pem $SHARED_CERT_DIR/docker-registry.scubbo.org.crt
# Note for if you're trying to debug this -
# `update-ca-certificates` resides in /usr/sbin, but will not show up unless `which` is run as root
update-ca-certificates

####
# Install Matrix client
####

USERNAME=$(hostname | perl -pe 's/ras/bot-/')
PASSWORD=$(date +%s | sha256sum | base64 | head -c 32)
echo "Run this command on a machine connected to the Kubernetes cluster:"
echo -n $'kubectl exec -it -n dendrite $(kubectl get pods --namespace dendrite -l "app.kubernetes.io/name=dendrite,app.kubernetes.io/instance=dendrite" -o jsonpath="{.items[0].metadata.name}") '
echo "-- /usr/bin/create-account -config /etc/dendrite/dendrite.yaml -username $USERNAME -password $PASSWORD -url http://localhost:8008"
echo
echo "Press enter when you have done so"
read
while true
do
  echo "Did you create the bot user? [y/n]"
  read response
  if [[ "$response" == "y" ]]; then
  	break
  else
  	echo "Well go do that then!"
  fi
done

mkdir -p /home/pi/.matrix
chown pi:pi /home/pi/.matrix
docker run -it -v /home/pi/.matrix:/data matrixcommander/matrix-commander --login password \
  --user-login $USERNAME --password $PASSWORD --homeserver matrix.scubbo.org --device $(hostname | perl -pe 's/ras//') \
  --room-default \#bot:matrix.scubbo.org
docker run -it -v /home/pi/.matrix:/data matrixcommander/matrix-commander --room-join \#bot:matrix.scubbo.org
docker run -it -v /home/pi/.matrix:/data matrixcommander/matrix-commander -m "Hello World, I am $USERNAME!"

# TODO - create a wrapper for all the docker arguments above
# TODO - make a `m` utility to just quickly send a message (using the saved credentials) without having to load up the docker container each time.
# I bet we can just curl a url with the appropriate access token or creds as headers!
