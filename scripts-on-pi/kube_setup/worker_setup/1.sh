#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

while getopts d: flag
do
    case "${flag}" in
        d) droneRPCSecret=${OPTARG};;
    esac
done

if [ -z "$droneRPCSecret" ]; then
  echo "Drone RPC Secret not set (get it from env vars of Drone on controller node)"
  exit 1
fi

####
# Mount NAS
####
mkdir /mnt/NAS
chown pi:pi /mnt/NAS
echo -e "rassigma.avril:/mnt/BERTHA\t/mnt/NAS\tnfs\tdefaults\t0\t0" >> /etc/fstab

####
# Set up fail2ban
####
ln -s /mnt/NAS/etc/fail2ban/jail.local /etc/fail2ban/jail.local
service fail2ban restart

# https://rancher.com/docs/k3s/latest/en/installation/private-registry/
mkdir -p /etc/rancher/k3s/
ln -s /mnt/NAS/etc/rancher/registries.yaml /etc/rancher/k3s/registries.yaml

####
# Install Drone runner
####
docker run \
    --volume=/var/run/docker.sock:/var/run/docker.sock \
    --env=DRONE_RPC_PROTO=http \
    --env=DRONE_RPC_HOST=rassigma.avril:3500 \
    --env=DRONE_RPC_SECRET=$droneRPCSecret \
    --env=DRONE_RUNNER_CAPACITY=2 \
    --env=DRONE_RUNNER_NAME=drone-runner \
    --env=DRONE_RUNNER_VOLUMES=/var/run/docker.sock:/var/run/docker.sock \
    --publish=3502:3000 \
    --restart=always \
    --detach=true \
    --name=runner \
    drone/drone-runner-docker:1
