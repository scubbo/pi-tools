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
    esac
done

if [ -z "$hostname" ]; then
  echo "Hostname not set"
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
# Install Bonjour
# https://www.howtogeek.com/167190/how-and-why-to-assign-the-.local-domain-to-your-raspberry-pi/
####
apt-get install avahi-daemon

####
# Install Docker
# https://phoenixnap.com/kb/docker-on-raspberry-pi
# TODO: consider switching to the Repo method: https://docs.docker.com/engine/install/ubuntu/
# When I tried it on 2021-08-30, there was no Buster version - seems we need to use armhf architecture
####
curl -fsSL https://get.docker.com -o get-docker.sh
sudo chmod +x get-docker.sh
sh ./get-docker.sh
rm get-docker.sh
usermod -aG docker pi
# This permission-change might not take effect until the session
# restarts - you may need to reconnect a new ssh session.

####
# Install pip (prerequisite for docker-compose)
####
apt-get install -y python3-distutils python3-apt python3-pip
# curl -s https://bootstrap.pypa.io/get-pip.py | python3

####
# Install boto3
####
pip3 install boto3

####
# Install docker-compose
# https://dev.to/elalemanyo/how-to-install-docker-and-docker-compose-on-raspberry-pi-1mo
####
apt-get install libffi-dev libssl-dev
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
sudo mkdir /mnt/BERTHA
berthaDev=$(blkid | grep 'BERTHAIII' | perl -pe 's/(.*):.*/$1/')
berthaUUID=$(blkid | grep 'BERTHAIII' | perl -pe 's/.* UUID="(.*?)".*/$1/')
echo "UUID=$berthaUUID /mnt/BERTHA exfat defaults,auto,users,rw,nofail,umask=000 0 0" >> /etc/fstab
mount -a

####
# Install jellyfin
####
docker pull jellyfin/jellyfin
docker run -d -v /mnt/BERTHA/etc/jellyfin/config/:/config -v /mnt/BERTHA/etc/jellyfin/cache/:/cache -v /mnt/BERTHA/media/:/media --net=host jellyfin/jellyfin:latest


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
# Install and run Prometheus
#
# Note this makes it only accessible from the Pi itself - would need to set up an ssh tunnel
# to view from laptop:
# $ ssh -N -L 9091:localhost:9090 <pi_name>
#
# --web.enable=lifecycle allows curling the `/-/reload` endpoint - https://github.com/prometheus/prometheus/issues/5986
####
docker run --name prometheus -d -p 127.0.0.1:9090:9090 --add-host host.docker.internal:host-gateway prom/prometheus \
  --web.enable-lifecycle \
  --config.file=/etc/prometheus/prometheus.yml
# ...and push-gateway server
docker run --name prom-gateway -d -p 127.0.0.1:9091:9091 prom/pushgateway

####
# Install and run Prometheus Exporter
# Note - intentionally run as a standalone process, not a Docker container. Think about it... :)
####
latestExporterVersion=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases | jq -r '.[] | .tag_name' | grep -v -E 'rc.?[[:digit:]]$' | perl -pe 's/^v//' | sort -V | tail -n 1)
wget -q -O /tmp/node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v${latestExporterVersion}/node_exporter-${latestExporterVersion}.linux-armv7.tar.gz
mv /tmp/node_exporter.tar.gz /opt
tar xvfz node_exporter.tar.gz
rm node_exporter.tar.gz
cd node_exporter-${latestExporterVersion}.linux-armv7
screen -d -m ./node_exporter

# And configure Prometheus to see the new metrics
# ...there _must_ be a better way...
# https://stackoverflow.com/questions/24319662/from-inside-of-a-docker-container-how-do-i-connect-to-the-localhost-of-the-mach
docker exec -i prometheus sh -c "echo -e '  - job_name: \"node\"\n    static_configs:\n      - targets: [\"host.docker.internal:9100\"]' >> /etc/prometheus/prometheus.yml"
docker exec -i prometheus sh -c "echo -e '  - job_name: \"pushGateway\"\n    static_configs:\n      - targets: [\"host.docker.internal:9091\"]' >> /etc/prometheus/prometheus.yml"
# Note - this next line is untested
# https://www.robustperception.io/reloading-prometheus-configuration
# If it doesn't work, do `docker restart prometheus`
curl -X POST http://localhost:9090/-/reload



####
# Install Grafana
# (Note - if desired, we could move this prep into the 1_setup script, to reduce
# duplicate `update`)
# https://grafana.com/tutorials/install-grafana-on-raspberry-pi/
# Note - should change password
####
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y grafana
/bin/systemctl enable grafana-server
/bin/systemctl start grafana-server
# Still need to set it up - e.g. add the Prometheus Data Source
