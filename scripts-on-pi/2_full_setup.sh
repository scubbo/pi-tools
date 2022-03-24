#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

while getopts h:u:p: flag
do
    case "${flag}" in
        h) hostname=${OPTARG};;
        u) grafanaUsername=${OPTARG};;
        p) grafanaPassword=${OPTARG};;
    esac
done

if [ -z "$hostname" ]; then
  echo "Hostname not set"
  exit 1
fi

if [ -z "$grafanaUsername" ]; then
  echo "Grafana Username not set"
  exit 1
fi

if [ -z "$grafanaPassword" ]; then
  echo "Grafana Password not set"
  exit 1
fi

if [ -z "$sambaPassword" ]; then
  echo "Samba Password not set"
  exit 1
fi

####
# Install Postfix so that Cron logs won't be discarded
# TODO: actual mail-out ability
####
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"
DEBIAN_FRONTEND=noninteractive apt-get install -y postfix

# Capture baseDir so that we can refer back to it later for e.g. configuration files, even after `cd`-ing around
baseDir=$(pwd)
if [ -z $(ls $baseDir | grep "2_full_setup.sh") ]; then
   echo "This script must be run from its own directory (\`./2_full_setup.sh\` rather than e.g. \`./pi-tools\scripts-on-pi/2_full_setup.sh\`).";
   exit 1
fi


####
# Change Hostname
# https://www.howtogeek.com/167195/how-to-change-your-raspberry-pi-or-other-linux-devices-hostname/
####
echo "Setting hostname to $hostname"
perl -i'' -pe "s/raspberrypi/$hostname/" /etc/hosts
echo $hostname > /etc/hostname

####
# Do all the apt-gets at once - more efficient that way!
# (Except postfix, because that has some unusual syntax)
# https://www.howtogeek.com/167190/how-and-why-to-assign-the-.local-domain-to-your-raspberry-pi/
####
apt-get install -y \
  avahi-daemon \
  python3-distutils python3-apt python3-pip python3-venv \
  libffi-dev libssl-dev \
  samba samba-common-bin \
  vim-gui-common vim-runtime \
  zsh

apt install -y fail2ban


command_exists() {
  command -v "$@" > /dev/null 2>&1
}

####
# Install Docker
# https://phoenixnap.com/kb/docker-on-raspberry-pi
# TODO: consider switching to the Repo method: https://docs.docker.com/engine/install/ubuntu/
# When I tried it on 2021-08-30, there was no Buster version - seems we need to use armhf architecture
####
if command_exists docker; then
  # This `command_exists` check is adapted from Docker itself:
  # https://get.docker.com/
  echo "Docker already installed - skipping"
else
  # Docker does not exist - install it
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo chmod +x get-docker.sh
  sh ./get-docker.sh
  rm get-docker.sh
  usermod -aG docker pi
  # This permission-change might not take effect until the session
  # restarts - you may need to reconnect a new ssh session.
fi


####
# Install boto3
####
pip3 install boto3

####
# Install docker-compose
# https://dev.to/elalemanyo/how-to-install-docker-and-docker-compose-on-raspberry-pi-1mo
####
apt -y install python3-dev
pip3 install docker-compose
# Note - still not part of $PATH. Update to bashrc?

####
# Set docker containers to auto-restart
# https://dev.to/elalemanyo/how-to-install-docker-and-docker-compose-on-raspberry-pi-1mo
####
systemctl enable docker

####
# Mount BERTHA
####
yes | apt install exfat-fuse
sudo mkdir -p /mnt/BERTHA
berthaDev=$(blkid | grep 'BERTHAIII' | perl -pe 's/(.*):.*/$1/')
berthaUUID=$(blkid | grep 'BERTHAIII' | perl -pe 's/.* UUID="(.*?)".*/$1/')
if [ -z "$berthaDev" ] || [ -z "$berthaUUID" ]; then
  echo "One of the bertha-variables is empty. Exiting (do you have the Hard Drive plugged in?"
  exit 1
fi
if [[ $(grep '/mnt/BERTHA' /etc/fstab | wc -l) -lt 1 ]]; then
  echo "UUID=$berthaUUID /mnt/BERTHA exfat defaults,auto,users,rw,nofail,exec,umask=000 0 0" >> /etc/fstab
fi
mount -a

####
# Install jellyfin
#
# Note Jellyfin's config will need to have ``<EnableMetrics>` set to `true` to enable Prometheus to see them.
# https://github.com/jellyfin/jellyfin/pull/2985
####
if [[ $(docker ps --filter "name=jellyfin" | wc -l) -lt 2 ]]; then
  docker pull jellyfin/jellyfin
  docker run -d \
    -v /mnt/BERTHA/etc/jellyfin/config/:/config \
    -v /mnt/BERTHA/etc/jellyfin/cache/:/cache \
    -v /mnt/BERTHA/media/:/media \
    --net=host \
    --name jellyfin \
    --restart always \
    jellyfin/jellyfin:latest
fi


# TODO: Pull RC files
# If you install Plex again, consider docker version:
# https://github.com/plexinc/pms-docker

# TODO - service-setup for hass-backup-sync-server.py,
# and crontab for the backup client

####
# Install jq
####
apt install -y jq  # Ah, simplicity :)


####
# Get configuration for Prometheus
# Note - consider doing this from the directly-pulled repo instead?
####
mkdir -p /etc/prometheus/
wget --quiet -O /etc/prometheus/prometheus.yml https://raw.githubusercontent.com/scubbo/pi-tools/main/config/prometheus.yml


####
# Install and run Prometheus
#
# Note this makes it only accessible from the Pi itself - would need to set up an ssh tunnel
# to view from laptop:
# $ ssh -N -L 9091:localhost:9090 <pi_name>
#
# --web.enable=lifecycle allows curling the `/-/reload` endpoint - https://github.com/prometheus/prometheus/issues/5986
# Should probably encapsulate this in a docker-compose...
####
if [[ $(docker network ls --filter name=prom-network | wc -l) -lt 2 ]]; then
  docker network create prom-network
fi
if [[ $(docker ps --filter "name=prometheus" | wc -l) -lt 2 ]]; then
  docker run --name prometheus \
    -d -p 127.0.0.1:9090:9090 \
    --net prom-network \
    --add-host host.docker.internal:host-gateway \
    -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
    --restart always \
    prom/prometheus \
    --web.enable-lifecycle \
    --config.file=/etc/prometheus/prometheus.yml
fi
if [[ $(docker ps --filter "name=prom-gateway" | wc -l) -lt 2 ]]; then
  docker run --name prom-gateway \
    -d -p 127.0.0.1:9091:9091 \
    --net prom-network \
    --restart always \
    prom/pushgateway
fi

####
# Install and run Prometheus Exporter
# Note - intentionally run as a standalone process, not a Docker container. Think about it... :)
####
latestExporterVersion=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases | jq -r '.[] | .tag_name' | grep -v -E 'rc.?[[:digit:]]$' | perl -pe 's/^v//' | sort -V | tail -n 1)
wget -q -O /tmp/node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v${latestExporterVersion}/node_exporter-${latestExporterVersion}.linux-armv7.tar.gz
tar xvfz /tmp/node_exporter.tar.gz
rm /tmpnode_exporter.tar.gz
mv node_exporter-${latestExporterVersion}.linux-armv7/node_exporter /usr/local/bin
# https://devopscube.com/monitor-linux-servers-prometheus-node-exporter/
sudo useradd -rs /bin/false node_exporter
sudo cp ../service-files/node_exporter.service /etc/systemd/system/
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

####
# Install Grafana
# (Note - if desired, we could move this prep into the 1_setup script, to reduce
# duplicate `update`)
# https://grafana.com/tutorials/install-grafana-on-raspberry-pi/
# Note - should change password
####
mkdir -p /mnt/BERTHA/etc/grafana
if [[ $(docker ps --filter "name=grafana" | wc -l) -lt 2 ]]; then
  docker run --name grafana \
    -d -p 3000:3000 \
    --net prom-network \
    -v /mnt/BERTHA/etc/grafana:/var/lib/grafana \
    -v /mnt/BERTHA/etc/grafana.ini:/etc/grafana/grafana.ini \
    --restart always \
    grafana/grafana-oss
fi
# Note - if the image is being set up from scratch, you still need to log in (admin/admin) and set it up

####
# Install PiVPN
####
curl -sL https://install.pivpn.io > install.sh
chmod +x install.sh
# TODO - shouldn't rely on relative directories for config - instead, save a location
./install.sh --unattended ../config/pi-vpn-options.conf
rm install.sh
echo "PiVPN installed (remember to open the appropriate Firewall port and add clients!)"

# Note - *this will fail*, because it doesn't have the secrets provided by the docker-compose.yml.
# Talk to Eamon about how to fix this (probably, Docker Swarm/k8s)
# Commenting this out because I suspect it's what brought down the Pi most-recently :shrug:
# docker run --name hass-backup \
#   -d \
#   -v /var/run/dbus:/var/run/dbus \
#   -v /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket \
#   -v /mnt/BERTHA/ha_backups:/host_system_dir \
#   --restart always \
#   scubbo/hass-backup \

####
# Configure fail2ban
# (note - already installed with `apt install`, above)
# https://pimylifeup.com/raspberry-pi-fail2ban/
####
ln -s /mnt/BERTHA/etc/fail2ban/jail.local /etc/fail2ban/jail.local
service fail2ban restart

####
# Make zsh the default shell
####
usermod --shell /bin/zsh pi

####
# Install dotfiles
####
pushd /home/pi
# TODO - this might fail because `sudo` operates with different ssh keys than main user?
git clone git@github.com:scubbo/dotfiles.git
# Note that we do _not_ use the `setup.sh` script that exists in that repo, since that's mostly intended
# for setting up an Amazon development laptop. But a lot of this is copied from it :)
sudo chown -R pi dotfiles
ln -s dotfiles/zshrc .zshrc
ln -s dotfiles/zshrc-local-pi .zshrc-local
ln -s dotfiles/zprofile .zprofile
ln -s dotfiles/gitignore_global .gitignore_global
rm -f .gitconfig
ln -s dotfiles/gitconfig .gitconfig
ln -s dotfiles/vimrc .vimrc
ln -s dotfiles/screenrc .screenrc
ln -s dotfiles/bin bin
popd

