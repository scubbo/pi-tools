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

# https://rancher.com/docs/k3s/latest/en/installation/private-registry/
# https://github.com/k3s-io/k3s/issues/1148#issuecomment-641687668 (for TLS certs for private registry)
# TODO - we do exactly the same thing here in worker_setup, but using a different path because that references
# `/mnt/NAS/...`. Maybe we should unify by having controller mount its own NFS filesystem?
mkdir -p /etc/rancher/k3s/
ln -s /mnt/BERTHA/etc/rancher/registries.yaml /etc/rancher/k3s/registries.yaml

curl -sfL https://get.k3s.io | sh -s - --config /mnt/BERTHA/etc/rancher/k3s/config.yaml
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
echo "\`curl -sfL https://get.k3s.io | sudo K3S_URL=https://$ipAddr:6443 K3S_TOKEN=$token sh -s -\`"
echo "(Don't forget to grab the file from /etc/rancher/k3s/k3s.yaml, change 127.0.0.1 to appropriate hostname, and save on laptop in ~/.kube/config!)"
echo
