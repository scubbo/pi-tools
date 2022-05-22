#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

####
# Set up fail2ban
####
ln -s /mnt/BERTHA/etc/fail2ban/jail.local /etc/fail2ban/jail.local
service fail2ban restart

####
# Set up Gitea
# https://docs.gitea.io/en-us/install-with-docker/ example requires docker-compose,
# but that requires a bunch of dependencies - we can do it by hand!
#
# Note to self - this didn't work first few times I tried (it only opened up the
# ssh server and not the web interface), so then I tried installing docker-compose
# and used the file provided from the website (which worked), and then ran the
# manual method below again and it worked. Not sure if I just didn't wait long enough
# the first time around, or what...
####
mkdir -p /mnt/BERTHA/gitea
sudo chown pi:pi /mnt/BERTHA/gitea
# Note - *not* `--internal`, despite the fact that the compose.yml file in the Gitea website
# includes `external: false`. They are not antonyms! `external` in a Compose file means
# "this network was created outside of a Compose context", not "this network is not-internal"
docker network create gitea
docker run -d --name gitea \
    --env USER_UID=1000 \
    --env USER_GID=1000 \
    --restart=always \
    --network=gitea \
    --mount type=bind,src=/mnt/BERTHA/gitea,dst=/data \
    --mount type=bind,src=/etc/timezone,dst=/etc/timezone,ro \
    --mount type=bind,src=/etc/localtime,dst=/etc/localtime,ro \
    -p 3000:3000 \
    -p 222:22 \
    gitea/gitea:latest
# Hopefully the first-time setup will be stored
# into the persistent storage!

####
# Set up Drone CI/CD.
# Note that the docs say they "do not recommend installing Drone and Gitea on the
# same machine due to network complications", but...we'll see how it goes :shrug:
# https://docs.drone.io/server/provider/gitea/
####
droneDir="/mnt/BERTHA/drone"
mkdir -p $droneDir
sudo chown pi:pi $droneDir

droneEtcDir="/mnt/BERTHA/etc/gitea-drone-oauth-secrets"
mkdir -p $droneEtcDir
sudo chown pi:pi $droneEtcDir

if [[ -f $droneEtcDir/clientId ]]; then
  clientId=$(cat $droneEtcDir/clientId)
  if [[ -z $clientId ]]; then
    echo "Client Id variable is empty"
    exit 1
  fi
else
  echo "Client Id file does not exist. Create an OAuth app in Gitea and record the values"
  exit 1
fi

if [[ -f $droneEtcDir/clientSecret ]]; then
  clientSecret=$(cat $droneEtcDir/clientSecret)
  if [[ -z $clientSecret ]]; then
    echo "Client Secret variable is empty"
    exit 1
  fi
else
  echo "Client Secret file does not exist. Create an OAuth app in Gitea and record the values"
  exit 1
fi

droneRPCSecret=$(openssl rand -hex 16)
# TODO - should Drone (particularly, runners) be managed via Kubernetes? It would be neater,
# but then we get into a circular dependency of not being able to build changes if k8s is down.
# Probably fine, since we can always start Drone manually outside k8s if necessary.

# Install Docker Server
docker run \
    --volume=$droneDir:/data \
    --env=DRONE_GITEA_SERVER=http://rassigma.avril:3000 \
    --env=DRONE_GITEA_CLIENT_ID=$clientId \
    --env=DRONE_GITEA_CLIENT_SECRET=$clientSecret \
    --env=DRONE_RPC_SECRET=$droneRPCSecret \
    --env=DRONE_SERVER_HOST=drone.scubbo.org \
    --env=DRONE_SERVER_PROTO=https \
    --env=DRONE_AGENTS_ENABLED=true \
    --publish=3500:80 \
    --publish=3501:443 \
    --restart=always \
    --detach=true \
    --name=drone \
    drone/drone:2
# (Runners will run on worker nodes)
echo "DRONE_RPC_SECRET for runners is $droneRPCSecret"



####
# Set up container registry
# (Do this independently of Kubernetes because it's part of bootstrapping the K8s cluster!)
####
# TODO - this assumes the drive has already been mounted
mkdir -p /mnt/BERTHA/image-registry
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v /mnt/BERTHA/image-registry:/var/lib/registry \
  registry:2

curl -sfL https://get.k3s.io | sh -
token=$(cat /var/lib/rancher/k3s/server/node-token)
ipAddr=$(ip addr | grep '192.168' | perl -pe 's/.*inet (.*?)\/24.*/$1/')
echo "Run the following command on agent nodes: \`curl -sfL https://get.k3s.io | sudo K3S_URL=https://$ipAddr:6443 K3S_TOKEN=$token sh -\`"
