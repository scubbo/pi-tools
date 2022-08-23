#!/bin/bash

# For utilities that should exist on all nodes, but aren't fundamental enough to belong in the 1st setup script

# No `set -x` here, as that would get noisy!
set -euo pipefail

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

####
# Install Matrix client
####

USERNAME=$(hostname | perl -pe 's/ras/bot-/')
PASSWORD=$(date +%s | sha256sum | base64 | head -c 32)
echo "Run this command on a machine connected to the Kubernetes cluster:"
echo -n $'kubectl exec -it -n dendrite $(kubectl get pods --namespace dendrite -l "app.kubernetes.io/name=dendrite,app.kubernetes.io/instance=dendrite" -o jsonpath="{.items[0].metadata.name}") '
echo "-- /usr/bin/create-account -config /etc/dendrite/dendrite.yaml -username $USERNAME -password $PASSWORD"
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