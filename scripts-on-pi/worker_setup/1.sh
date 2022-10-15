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

# https://unix.stackexchange.com/a/146341
export DEBIAN_FRONTEND=noninteractive

####
# Mount NAS
####
mkdir /mnt/NAS
chown pi:pi /mnt/NAS
echo -e "rassigma.avril:/mnt/BERTHA\t/mnt/NAS\tnfs\tdefaults\t0\t0" >> /etc/fstab
mount -a

####
# Set up fail2ban
####
ln -s /mnt/NAS/etc/fail2ban/jail.local /etc/fail2ban/jail.local
service fail2ban restart

# https://rancher.com/docs/k3s/latest/en/installation/private-registry/
mkdir -p /etc/rancher/k3s/
ln -s /mnt/NAS/etc/rancher/registries.yaml /etc/rancher/k3s/registries.yaml
mkdir -p /etc/rancher/k3s/cert.d/docker-registry.scubbo.org
cp -L /mnt/NAS/certs/live/docker-registry.scubbo.org/chain.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/ca.crt
cp -L /mnt/NAS/certs/live/docker-registry.scubbo.org/cert.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/client.cert
cp -L /mnt/NAS/certs/live/docker-registry.scubbo.org/privkey.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/client.key


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

echo "Now run the following command on the main server node, and it will output a command that you should run here to join the k3s cluster"
echo
echo $'echo "curl -sfL https://get.k3s.io | sudo K3S_URL=https://$(ip addr | grep \'192.168\' | perl -pe \'s/.*inet (.*?)\/24.*/$1/\'):6443 K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token) sh -"'
