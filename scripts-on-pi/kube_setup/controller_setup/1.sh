#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# https://unix.stackexchange.com/a/146341
export DEBIAN_FRONTEND=noninteractive

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
  echo "UUID=$berthaUUID /mnt/BERTHA ext4 defaults,nofail 0 2" >> /etc/fstab
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
  # Need to permit mounting from 127.0.0.1 because otherwise pods that run on the controller won't be able to access NFS!
  # (Could have done this in a one-liner, but this makes it more explicit that the options are the same)
  echo "/mnt/BERTHA 127.0.0.1(rw,all_squash,insecure,async,no_subtree_check,anonuid=1000,anongid=1000)" >> /etc/exports
fi
exportfs -ra


####
# Set up fail2ban
####
ln -s /mnt/BERTHA/etc/fail2ban/jail.local /etc/fail2ban/jail.local
service fail2ban restart

####
# Set up postfix (not just for email, enables logging from CRON)
####
debconf-set-selections <<< "postfix postfix/mailname string $(hostname)"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"
apt-get install -y postfix


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

# https://rancher.com/docs/k3s/latest/en/installation/private-registry/
# https://github.com/k3s-io/k3s/issues/1148#issuecomment-641687668 (for TLS certs for private registry)
# TODO - we do exactly the same thing here in worker_setup, but using a different path because that references
# `/mnt/NAS/...`. Maybe we should unify by having controller mount its own NFS filesystem?
mkdir -p /etc/rancher/k3s/
ln -s /mnt/BERTHA/etc/rancher/registries.yaml /etc/rancher/k3s/registries.yaml
# Note that, unlike for Docker, you do not need to encode the port in the directory name here -
# in fact, that directory name is arbitrary (and will be referenced direclty in registries.yaml)
mkdir -p /etc/rancher/k3s/cert.d/docker-registry.scubbo.org
cp -L /mnt/BERTHA/certs/live/docker-registry.scubbo.org/chain.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/ca.crt
cp -L /mnt/BERTHA/certs/live/docker-registry.scubbo.org/cert.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/client.cert
cp -L /mnt/BERTHA/certs/live/docker-registry.scubbo.org/privkey.pem /etc/rancher/k3s/cert.d/docker-registry.scubbo.org/client.key

curl -sfL https://get.k3s.io | sh -
# Install krew (kubectl plugin manager) before finishing the script with the
# output that describes how to add other nodes to the kubernetes cluster
# https://krew.sigs.k8s.io/docs/user-guide/setup/install/
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)


token=$(cat /var/lib/rancher/k3s/server/node-token)
ipAddr=$(ip addr | grep '192.168' | perl -pe 's/.*inet (.*?)\/24.*/$1/')
echo
echo "==========================="
echo
echo "Run the following command on agent nodes after you have created /etc/rancher/k3s/registries.yaml:"
echo "\`curl -sfL https://get.k3s.io | sudo K3S_URL=https://$ipAddr:6443 K3S_TOKEN=$token sh -\`"
echo "(Don't forget to grab the file from /etc/rancher/k3s/k3s.yaml, change 127.0.0.1 to appropriate hostname, and save on laptop in ~/.kube/config!)"
echo
echo "Note you haven't set up Dynamic DNS - prerequisite is to pull in pi-tools"
echo "When you've done that, update this script with: echo \"* * * * * pi ./updateDNS.py --dns-name vpn.scubbo.org --token-file-location /mnt/BERTHA/etc/scubbo-cf-dyndns/token\" > /etc/cron.d/scubbo-cf-dyndns"
echo "Note - must be pi (not root) because of location of pi-tools and logging"
echo
echo "Also ensure that DNS server reports this node's IP address ($ipAddr) for docker-registry.scubbo.org"
