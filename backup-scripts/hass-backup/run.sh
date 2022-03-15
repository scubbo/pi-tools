#!/bin/sh

while true; do
  echo "Waking up to copy Hass backups"
  echo "First, moving old backups to a backup-backup location"
  mkdir -p /host_system_dir/old_backups
  rm -rf /host_system_dir/old_backups/*
  mv /host_system_dir/*.tar /host_system_dir/old_backups
  echo "Now, copying off of the remote host"
  scp -i /run/secrets/user_ssh_key -o StrictHostKeyChecking=no -p 25 "root@homeassistant.local:/backup/*" /host_system_dir/
  echo "Finished copying backup to BERTHA"
  sleep 18000 # 5 hours
done