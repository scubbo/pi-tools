#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

####
# Mount Bertha...
####
mkdir -p /mnt/BERTHA
chown pi:pi /mnt/BERTHA
berthaDev=$(blkid | grep 'BERTHAIV' | perl -pe 's/(.*):.*/$1/')
berthaUUID=$(blkid | grep 'BERTHAIV' | perl -pe 's/.* UUID="(.*?)".*/$1/')
if [ -z "$berthaDev" ] || [ -z "$berthaUUID" ]; then
  echo "One of the bertha-variables is empty. Exiting (do you have the Hard Drive plugged in?"
  exit 1
fi
if [[ $(grep '/mnt/BERTHA' /etc/fstab | wc -l) -lt 1 ]]; then
  echo "UUID=$berthaUUID /mnt/BERTHA ext4 defaults 0 2" >> /etc/fstab
fi
mount -a

####
# ...and share via NFS
# https://pimylifeup.com/raspberry-pi-nfs/
####
apt-get install -y nfs-kernel-server
if [[ $(grep '/mnt/BERTHA' /etc/exports | wc -l) -lt 1 ]]; then
  # Note - this hard-codes the IDs' of `pi` user. If needed to be dynamic, you can
  # fetch them by parsing the output of `id pi`
  echo "/mnt/BERTHA 192.168.1.0/24(rw,all_squash,insecure,async,no_subtree_check,anonuid=1000,anongid=1000)" >> /etc/exports
fi
exportfs -ra

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
chown pi:pi /mnt/BERTHA/gitea
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
chown pi:pi $droneDir

droneEtcDir="/mnt/BERTHA/etc/gitea-drone-oauth-secrets"
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
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v /mnt/BERTHA/image-registry:/var/lib/registry \
  registry:2

# https://rancher.com/docs/k3s/latest/en/installation/private-registry/
mkdir -p /etc/rancher/k3s/
ln -s /mnt/BERTHA/etc/rancher/registries.yaml /etc/rancher/k3s/registries.yaml

curl -sfL https://get.k3s.io | sh -
token=$(cat /var/lib/rancher/k3s/server/node-token)
ipAddr=$(ip addr | grep '192.168' | perl -pe 's/.*inet (.*?)\/24.*/$1/')
echo "Run the following command on agent nodes after you have created /etc/rancher/k3s/registries.yaml:"
echo "\`curl -sfL https://get.k3s.io | sudo K3S_URL=https://$ipAddr:6443 K3S_TOKEN=$token sh -\`"
echo "(Don't forget to grab the file from /etc/rancher/k3s/k3s.yaml, change 127.0.0.1 to appropriate hostname, and save on laptop in ~/.kube/config!)"
echo
echo "Note you haven't set up Dynamic DNS - prerequisite is to pull in pi-tools"
echo "When you've done that, update this script with: echo \"* * * * * pi ./updateDNS.py --dns-name vpn.scubbo.org --token-file-location /mnt/BERTHA/etc/scubbo-cf-dyndns/token\" > /etc/cron.d/scubbo-cf-dyndns"
echo "Note - must be pi (not root) because of location of pi-tools and logging"
