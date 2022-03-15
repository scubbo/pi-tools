#!/bin/sh

while true; do
  echo "Waking up to copy Hass backups"
  echo "First, moving old backups to a backup-backup location"
  mkdir -p /host_system_dir/old_backups
  rm -rf /host_system_dir/old_backups/*
  mv /host_system_dir/*.tar /host_system_dir/old_backups 2>/dev/null
  echo "Now, copying off of the remote host"
  # I had a hell of a time trying to get mDNS discovery working from a Docker container!
  # This feels really janky, but hey, it works.
  # Some references if you try to implement this better:
  # https://gnanesh.me/avahi-docker-non-root.html
  # https://github.com/lathiat/nss-mdns
  # https://stackoverflow.com/a/62502769/1040915
  ipAddr=$(avahi-browse -trp -d local _workstation._tcp | grep '^=;(null);IPv4;homeassistant' | cut -d ';' -f8)
  scp -i /run/secrets/user_ssh_key -o StrictHostKeyChecking=no -P 25 "root@$ipAddr:/backup/*" /host_system_dir/
#  for filename in $(ssh -i /run/secrets/user_ssh_key -o StrictHostKeyChecking=no -p 25 "root@$ipAddr" "ls /backup"); do
#    echo "Copying $filename";
#    scp -i /run/secrets/user_ssh_key -o StrictHostKeyChecking=no -P 25 "root@$ipAddr:/backup/$filename" /host_system_dir/;
#  done
  echo "Finished copying backup to BERTHA"
  sleep 18000 # 5 hours
done
