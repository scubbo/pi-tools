#!/usr/bin/python3


from argparse import ArgumentParser
from errno import EPERM
from paramiko import SSHClient, AutoAddPolicy
from pathlib import Path
from scp import SCPClient
from shutil import copy, move
from sys import exit
from tempfile import TemporaryDirectory

def do_copy(scp):
  previous_backups = Path('previous_backups')
  if not previous_backups.exists():
    previous_backups.mkdir()

  current_path = Path('.')
  for f in current_path.iterdir():
    if f.suffix == '.tar':
      f.rename(previous_backups.joinpath(f))


  # Cannot scp directly to the destination directory because permissions
  # are funky on mounted drives :(
  with TemporaryDirectory() as td:
    scp.get(remote_path='/backup/*.tar', local_path=td)
    print('Files downloaded - moving into place')
    for downloaded in Path(td).iterdir():
      print(f'Moving {downloaded.name}')
      # Cannot use `downloaded.rename`, because that uses os.rename under the hood,
      # and that errors with "Invalid cross-device link" when copying across filesystems
      try:
        move(downloaded, current_path.joinpath(downloaded.name))
      except OSError as err:
        # Copying files to an NTFS filesystem will cause errors when
        # trying to set permissions.
        # https://bugs.python.org/issue1545
        if err.errno != EPERM:
          raise



  # If there are no .tars in this directory, then something has gone wrong
  # and we should error out. Otherwise, we can safely delete the `previous_backups`
  if not any(filter(lambda p: p.suffix == '.tar', current_path.iterdir())):
    print('No backups were copied over! Erroring out. Previous backups maintained')
    sys.exit(1)
  else:
    for pb in previous_backups.iterdir():
      pb.unlink()
    previous_backups.rmdir()


if __name__ == '__main__':
  parser = ArgumentParser()
  parser.add_argument('--host', default='homeassistant.local')
  parser.add_argument('--port', type=int, default=22)
  parser.add_argument('--username', default='root')
  parser.add_argument('--key-name', default='id_rsa')
  args = parser.parse_args()
  with SSHClient() as ssh:
    ssh.load_system_host_keys()
    ssh.set_missing_host_key_policy(AutoAddPolicy())
    ssh.connect(args.host, port=args.port, username=args.username, key_filename=str(Path().home().joinpath('.ssh').joinpath(args.key_name)))

    # https://stackoverflow.com/a/47926522/1040915
    with SCPClient(ssh.get_transport(), sanitize=lambda x: x) as scp:
      do_copy(scp)
