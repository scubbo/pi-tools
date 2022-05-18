#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

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