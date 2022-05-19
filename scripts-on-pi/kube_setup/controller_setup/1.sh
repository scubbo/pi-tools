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
echo "Run the following command on agent nodes: \`curl -sfL https://get.k3s.io | K3S_URL=https//$ipAddr:6443 K3S_TOKEN=$token sudo sh -\`"