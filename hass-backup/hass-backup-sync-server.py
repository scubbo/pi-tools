#!/usr/bin/python3

import logging
from logging.handlers import RotatingFileHandler

import contextlib
import json
import socketserver
import tarfile

from argparse import ArgumentParser
from datetime import datetime
from errno import EPERM
from paramiko import SSHClient, AutoAddPolicy
from pathlib import Path
from scp import SCPClient
from shutil import copy, move, rmtree
from sys import exit
from tempfile import TemporaryDirectory

# https://github.com/prometheus/client_python#exporting-to-a-pushgateway
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)
handlers = [
  RotatingFileHandler('logging.log', maxBytes=2000, backupCount=3),
  logging.StreamHandler()
]

formatter = logging.Formatter('%(asctime)-15s - %(message)s')
for handler in handlers:
  handler.setFormatter(formatter)
  LOGGER.addHandler(handler)

HOST = 'localhost'
PORT = 9999

# Prometheus variables
prometheus_registry = CollectorRegistry()
LATEST_BACKUP_TIMESTAMP = Gauge('hassbackup_latest_backup_timestamp', 'Timestamp when the latest backup was created', registry=prometheus_registry)
LATEST_SYNC_TIMESTAMP = Gauge('hassbackup_latest_sync_timestamp', 'Timestamp when the last sync was carried out', registry=prometheus_registry)


def start_backup_sync_server():
  """
  Starts a TCP server that can be pinged to trigger a pull of backups
  """
  class BackupSyncHandler(socketserver.BaseRequestHandler):
    # https://docs.python.org/3/library/socketserver.html#socketserver-tcpserver-example
    def handle(self):
      # self.request is the TCP socket connected to the client
      data = self.request.recv(1024).strip()
      LOGGER.debug(f"BackupSyncServer received {data} from {self.client_address[0]}")
      if data.startswith(bytes('sync-backup ', 'utf-8')):
        with _make_scp(**self._parse_input(data)) as scp:
          _do_copy(scp)
      else:
        LOGGER.error(f'Received unexpected data: {data}')
      self.request.sendall(bytes('Thx!', 'utf-8'))

    def _parse_input(self, inp):
      # Assumes that inp begins with `sync-backup `, and format of:
      # `key1=val1 key2=val2`
      # No validation!
      vals = dict([i.split('=') for i in inp.decode('utf-8')[len('sync-backup '):].split(' ')])
      if 'host' not in vals:
        vals['host'] = 'homeassistant.local'
      if 'port' not in vals:
        vals['port'] = 22
      else:
        vals['port'] = int(vals['port'])
      if 'username' not in vals:
        vals['username'] = 'root'
      if 'key_name' not in vals:
        vals['key_name'] = 'id_rsa'
      return vals

  with socketserver.TCPServer((HOST, PORT), BackupSyncHandler) as server:
    LOGGER.info('Starting sync server')
    server.serve_forever()


@contextlib.contextmanager
def _make_scp(**kw_args):
  ssh = SSHClient()
  try:
    ssh.load_system_host_keys()
    ssh.set_missing_host_key_policy(AutoAddPolicy())
    ssh.connect(kw_args['host'], port=kw_args['port'], username=kw_args['username'], key_filename=str(Path().home().joinpath('.ssh').joinpath(kw_args['key_name'])))

    # https://stackoverflow.com/a/47926522/1040915
    scp = SCPClient(ssh.get_transport(), sanitize=lambda x: x)
    try:
      yield scp
    finally:
      scp.close()
  finally:
    ssh.close()

def _do_copy(scp):
  previous_backups = Path('previous_backups')
  if not previous_backups.exists():
    previous_backups.mkdir()

  backups = Path('backups')
  if not backups.exists():
    backups.mkdir()
  for f in backups.iterdir():
    if f.suffix == '.tar':
      f.rename(previous_backups.joinpath(f.name))


  # Cannot scp directly to the destination directory because permissions
  # are funky on mounted drives :(
  with TemporaryDirectory() as td:
    LOGGER.info('Downloading files')
    scp.get(remote_path='/backup/*.tar', local_path=td)
    LOGGER.info('Files downloaded - moving into place')
    for downloaded in Path(td).iterdir():
      LOGGER.debug(f'Moving {downloaded.name}')
      # Cannot use `downloaded.rename`, because that uses os.rename under the hood,
      # and that errors with "Invalid cross-device link" when copying across filesystems
      try:
        move(downloaded, backups.joinpath(downloaded.name))
      except OSError as err:
        # Copying files to an NTFS filesystem will cause errors when
        # trying to set permissions.
        # https://bugs.python.org/issue1545
        if err.errno != EPERM:
          raise
  LOGGER.info('Moving complete')


  # If there are no .tars in this directory, then something has gone wrong
  # and we should error out. Otherwise, we can safely delete the `previous_backups`
  if not any(filter(lambda p: p.suffix == '.tar', backups.iterdir())):
    log.error('No backups were copied over! Erroring out. Previous backups maintained')
    sys.exit(1)
  else:
    rmtree(str(previous_backups), ignore_errors=True)

  LATEST_SYNC_TIMESTAMP.set_to_current_time()
  LATEST_BACKUP_TIMESTAMP.set(int(max([_get_timestamp_of_backup(b) for b in backups.iterdir() if b.suffix == '.tar']).timestamp()))
  push_to_gateway('localhost:9091', job='hass_backup', registry=prometheus_registry)

def _get_timestamp_of_backup(backup_path: Path):
  info = _get_info_from_backup(backup_path)
  return datetime.strptime(info['date'], '%Y-%m-%dT%H:%M:%S.%f%z')

def _get_info_from_backup(backup_path: Path):
  possible_file_names = ['snapshot.json', 'backup.json']
  # https://stackoverflow.com/a/62777331/1040915
  exc = None
  for file_name in possible_file_names:
    try:
      return json.load(tarfile.open(str(backup_path)).extractfile(f'./{file_name}'))
    except Exception as e:
      exc = e
  else:
    LOGGER.exception(e)
    LOGGER.error(f'Error while handling {backup_path}')
    raise exc


if __name__ == '__main__':
  start_backup_sync_server()
