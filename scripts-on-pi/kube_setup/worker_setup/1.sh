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
mkdir -p /etc/rancher/k3s/cert.d/docker-registry.scubbo.org
cp -L /mnt/BERTHA/certs/live/docker-registry.scubbo.org/chain.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/ca.crt
cp -L /mnt/BERTHA/certs/live/docker-registry.scubbo.org/cert.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/client.cert
cp -L /mnt/BERTHA/certs/live/docker-registry.scubbo.org/privkey.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/client.key


####
# Install Drone runner
#
# Note that we cannot mount the certificate directly into desired location (`/etc/docker/certs.d/<host:port>/ca.crt`),
# because the mounting doesn't support paths with colons. Instead we mount to a simple path in the root, then
# copy it into place in the CI/CD steps: https://gitea.scubbo.org/scubbo/blogContent/src/commit/563a73a5725d94d01201ba443df7f7f051fa8b28/.drone.yml#L22-L23
# https://stackoverflow.com/questions/72823418/how-to-make-drone-docker-plugin-use-self-signed-certs
####
docker run \
    --volume=/var/run/docker.sock:/var/run/docker.sock \
    --env=DRONE_RPC_PROTO=http \
    --env=DRONE_RPC_HOST=rassigma.avril:3500 \
    --env=DRONE_RPC_SECRET=$droneRPCSecret \
    --env=DRONE_RUNNER_CAPACITY=2 \
    --env=DRONE_RUNNER_NAME=drone-runner \
    --env=DRONE_RUNNER_VOLUMES=/var/run/docker.sock:/var/run/docker.sock,$(readlink -f /mnt/NAS/certs/live/docker-registry.scubbo.org/chain.pem):/registry_cert.crt \
    --publish=3502:3000 \
    --restart=always \
    --detach=true \
    --name=runner \
    drone/drone-runner-docker:1
