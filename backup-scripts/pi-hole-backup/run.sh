#!/bin/sh

while true; do
  echo "Waking up to copy pi-hole backups"
  ssh -i /run/secrets/user_ssh_key -o StrictHostKeyChecking=no pi@192.168.42.74 "pihole -a -t";
  # Instead of using an intermediate filename, I tried passing the output to `xargs -I {} scp ...`, but the file could not be found.
  filename=$(ssh -i /run/secrets/user_ssh_key -o StrictHostKeyChecking=no pi@192.168.42.74 "ls -tr *.tar.gz | tail -n1");
  scp -i /run/secrets/user_ssh_key -o StrictHostKeyChecking=no "pi@192.168.42.74:$filename" /host_system_dir/
  ssh -i /run/secrets/user_ssh_key -o StrictHostKeyChecking=no pi@192.168.42.74 "rm pi-hole-teleporter*.tar.gz"
  echo "Finished copying backup to BERTHA"
  # Keep 2 days of backups
  # TODO - find a way to do exponential backoff - e.g. keep the 3 latest, then one from a week ago and one from a month ago
  find /host_system_dir -mtime +2 -type f -delete
  sleep 18000 # 5 hours
done
