#!/usr/bin/env python3

from fabric import Connection
from pathlib import Path

conn = Connection('192.168.42.74', user='pi', connect_kwargs={'key_filename':str(Path().home().joinpath('.ssh').joinpath('id_rsa'))})

conn.run('pihole -a -t', hide=True)
backup_name = conn.run('ls pi-hole*', hide=True).stdout.strip().splitlines()[-1]
conn.get(backup_name, f'/host_system_dir/{backup_name}')

# TODO - run a limitation on the backups
# TODO - emit Prometheus metrics
