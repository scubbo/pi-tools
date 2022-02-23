#!/bin/bash

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

while getopts h: flag
do
    case "${flag}" in
        h) hostname=${OPTARG};;
        gu) grafanaUsername=${OPTARG};;
        gp) grafanaPassword=${OPTARG};;
        sp) sambdaPassword=${OPTARG};;
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
####
apt-get install -y \
  # Install Bonjour
  # https://www.howtogeek.com/167190/how-and-why-to-assign-the-.local-domain-to-your-raspberry-pi/
  avahi-daemon \
  # pip (prerequisite for docker-compose)
  python3-distutils python3-apt python3-pip
  # More docker-compose prereqs
  libffi-dev libssl-dev \
  # Samba Share
  # https://pimylifeup.com/raspberry-pi-samba/
  samba samba-common-bin \
  # Update vim
  vim-gui-common vim-runtime \
  zsh


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
apt install python3-dev
pip3 install docker-compose
# Note - still not part of $PATH. Update to bashrc?

####
# Set docker containers to auto-restart
# https://dev.to/elalemanyo/how-to-install-docker-and-docker-compose-on-raspberry-pi-1mo
####
sudo systemctl enable docker

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

####
# Set up Samba share
# https://pimylifeup.com/raspberry-pi-samba/
#
# (NFS doesn't work on FAT drives)
####
mkdir -p /mnt/BERTHA/share
echo -e "\n[berthashare]\npath = /mnt/BERTHA/share\nwriteable=Yes\ncreate mask=0777\ndirectory mask=0777\npublic=no\n" | sudo tee -a /etc/samba/smb.conf > /dev/null
useradd sambpi # The link above neglects to mention this! (Because they reuse the existing `pi` user)
yes "$sambaPassword" | head -n 2 | smbpasswd -s -a sambpi
systemctl restart smbd


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
curDir=$(pwd)
latestExporterVersion=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases | jq -r '.[] | .tag_name' | grep -v -E 'rc.?[[:digit:]]$' | perl -pe 's/^v//' | sort -V | tail -n 1)
wget -q -O /tmp/node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v${latestExporterVersion}/node_exporter-${latestExporterVersion}.linux-armv7.tar.gz
mv /tmp/node_exporter.tar.gz /opt
cd /opt
tar xvfz node_exporter.tar.gz
rm node_exporter.tar.gz
cd node_exporter-${latestExporterVersion}.linux-armv7
screen -d -m ./node_exporter
cd $curDir

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
    --net prom-network
    -v /mnt/BERTHA/etc/grafana:/var/lib/grafana \
    --restart always \
    grafana/grafana-oss
fi
# Note - if the image is being set up from scratch, you still need to log in (admin/admin) and set it up

####
# Install PiVPN
####
curl -L https://install.pivpn.io > install.sh
chmod +x install.sh
# TODO - shouldn't rely on relative directories for config - instead, save a location
./install.sh --unattended ../config/pi-vpn-options.conf
rm install.sh
echo "PiVPN installed (remember to open the appropriate Firewall port and add clients!)"

####
# Run the sync-server
# TODO - probably need to source this somehow, cannot assume it will be present in ha_backups?
####
pushd /mnt/BERTHA/ha_backups && screen -d -m ./hass-backup-sync-server.py && popd
echo "*/10 * * * * pi /mnt/BERTHA/ha_backups/hass-backup-sync-client.py sync-backup port=25 key_name=hassio_internal_key" > /etc/cron.d/hass-client-backup

####
# Make zsh the default shell
####
usermod --shell /bin/zsh pi

####
# Install dotfiles
####
pushd /home/pi
git clone git@github.com:scubbo/dotfiles.git
# Note that we do _not_ use the `setup.sh` script that exists in that repo, since that's mostly intended
# for setting up an Amazon development laptop. But a lot of this is copied from it :)
sudo chown -R pi dotfiles
ln -s dotfiles/zshrc .zshrc
ln -s dotfiles/zshrc-local-pi .zshrc-local
ln -s dotfiles/zprofile .zprofile
ln -s dotfiles/gitignore_global .gitignore_global
rm .gitconfig
ln -s dotfiles/gitconfig .gitconfig
ln -s dotfiles/vimrc .vimrc
ln -s dotfiles/screenrc .screenrc
ln -s dotfiles/bin bin
popd

