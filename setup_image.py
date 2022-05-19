#!/usr/bin/env python3

import argparse
import binascii
import datetime
import functools
import hashlib
import lzma
import os
import re
import requests
import select
import signal
import sys
import tarfile
import time


from pathlib import Path
from shutil import copyfileobj
from string import Template
from subprocess import check_output, Popen, PIPE
from sys import exit # Intentional - I prefer just `exit` to `sys.exit`, but `platform` looks weird
from tempfile import TemporaryDirectory
from zipfile import ZipFile


try:
  from tqdm import tqdm
except ImportError:
  print('Failed to import tqdm')
  exit(1)

CHUNK_SIZE=1024


BASE_IMAGE_DIRECTORY_URL = Template('https://downloads.raspberrypi.org/$type/images/')
IMAGE_TYPES = {
  'lite': {'image_directory': 'raspios_lite_armhf'},
  'lite64': {'image_directory': 'raspios_lite_arm64'}
}
# Not worth importing BeautifulSoup just for a little bit of finding within html
DIRECTORY_SEARCH_REGEX = '<tr>(.*?)</tr>'
NAME_WITHIN_ROW_REGEX = '<td><a href="(.*?)">'
FILE_NAME_REGEX = '<td><a href="(.*?\.xz)">'
# Regex for a different purpose - for parsing `diskutil list`
DISK_NUMBER_REGEX = '/dev/disk(\d).*'

def create(args):
  # Do this first because it's the part that needs interactivity
  disk_number_and_info = _find_disk_number_and_info()
  print(f'Best guess is that disk number is {disk_number_and_info[0]}, with following info:')
  print(disk_number_and_info[1])
  response = input('If correct, enter "yes": ')
  # TODO - allow entering other disk numbers
  if response != 'yes':
    exit(1)

  image_file_path = _get_image_file_path(args)
  _write_image_to_disk(image_file_path, disk_number_and_info[0])


def _get_image_file_path(args) -> Path:
  if args.image_file:
    image_file_path = Path(args.image_file)
    # TODO - check if there is a later version from the net
  else:
    image_file_path_raw = input('Path to image file? (leave blank to download) >> ')
    if not image_file_path_raw:
      print('Downloading image from internet')
      with TemporaryDirectory() as temp_dir:
        image_file_path = _download_image_file_and_return_file_path(Path(temp_dir), args.image_type)
    else:
      image_file_path = Path(image_file_path_raw)
  if not image_file_path.exists():
    print(f'Path {image_file_path} does not exist - erroring out')
    exit(1)

  return image_file_path


def _find_url_of_latest_image(image_type: str) -> str:
  directory_url = BASE_IMAGE_DIRECTORY_URL.substitute({'type': IMAGE_TYPES[image_type]['image_directory']})
  image_directory = requests.get(directory_url)
  latest_image_row = re.findall(DIRECTORY_SEARCH_REGEX, image_directory.text)[-2]
  latest_image_name = re.search(NAME_WITHIN_ROW_REGEX, latest_image_row)[1]

  latest_image_directory = requests.get(directory_url + latest_image_name)
  file_name = re.search(FILE_NAME_REGEX, latest_image_directory.text)[1]
  full_url = directory_url + latest_image_name + file_name
  return full_url

def _download_image_file_and_return_file_path(temp_dir, image_type: str):
  full_url = _find_url_of_latest_image(image_type)
  print(f'Downloading LZMAFile from {full_url} to {temp_dir}')
  path_to_lzma = temp_dir.joinpath('image.xz')

  download_request = requests.get(full_url, stream=True)
  content_length = int(download_request.headers.get('content-length'))
  # https://stackoverflow.com/a/63831344/1040915
  download_request.raw.read = functools.partial(download_request.raw.read, decode_content=True)
  with tqdm.wrapattr(download_request.raw, "read", total=content_length) as tq:
    with open(path_to_lzma, 'wb') as f:
      copyfileobj(tq, f)

  print(f'Finished downloading LZMAFile to {path_to_lzma}')
  extract_dir = Path.home().joinpath('raspi_image')
  extract_dir.mkdir(exist_ok=True)
  extract_location = extract_dir.joinpath(str(int(datetime.datetime.now().timestamp())))
  # https://stackoverflow.com/a/72206813/1040915 - thanks, SO!
  with lzma.open(path_to_lzma) as f_in:
    with open(extract_location, 'wb') as f_out:
      f_out.write(f_in.read())

  path_to_lzma.unlink()
  print(f'Extracted LZMAFile to {extract_location}')

  return extract_location

def _find_disk_number_and_info():
  # This script is only tested on Mac - can't guarantee it will work elsewhere.
  # Feel free to remove this check locally if you know what you're doing!
  if sys.platform != 'darwin':
    print(f'This script is only tested on Mac - your platform is {sys.platform}. Proceed at your own caution')
    exit(1)

  op = Popen(['diskutil', 'list'], stdout=PIPE)\
             .stdout.read().decode('ascii')
  lines = op.splitlines()
  disk_number = -1
  info = ''
  for line in lines:
    match = re.match(DISK_NUMBER_REGEX, line)
    if match:
      if line.endswith(' (external, physical):'):
        info = ''
        in_matching_disk = True
        disk_number = int(match[1])
      else:
        # We are in an info-block for an ineligible disk - stop accumulating info-lines
        in_matching_disk = False
    else:
      # Not a disk-identifying line - if we are within an eligible disk's info block, accumulate info-lines; else, move on
      if in_matching_disk:
        info += f'\n{line}'
  if disk_number == -1:
    print(f'Failed to find any eligible disk from `diskutil list`')
    exit(1)
  return (disk_number, info)


def _write_image_to_disk(image_file_path: Path, disk_number: int):
  print(f'Writing image from {image_file_path} to disk {disk_number}')
  um_response = Popen(['sudo', 'diskutil', 'unmountDisk', f'/dev/disk{disk_number}'], stderr=PIPE)\
                     .stderr.read().decode('ascii')
  if um_response.startswith(f'Unmount of disk{disk_number} failed:'):
    print(um_response)
    exit(1)
  time.sleep(0.1)

  # https://gist.github.com/hikoz/741643, though needed some tweaking for Python3
  dd = Popen(['dd', 'bs=1m', f'if={image_file_path.absolute()}', f'of=/dev/rdisk{disk_number}'], stderr=PIPE)
  # https://stackoverflow.com/a/10759061/1040915
  poll_obj = select.poll()
  poll_obj.register(dd.stderr, select.POLLIN)
  try:
    while dd.poll() is None:
      time.sleep(.3)
      # Note - `SIGUSR1` if not on Mac
      dd.send_signal(signal.SIGINFO)
      poll_result = poll_obj.poll(2000)
      if poll_result:
        l = dd.stderr.readline().decode('ascii')
        if 'records in' in l:
          print(f'{l[:l.index("+")]} records, ', end='')
        if 'bytes' in l:
          print(f'{l.strip()}\r', end='')
      else:
        # No poll result
        break
    else:
      print(f'Image-write complete')
  except KeyboardInterrupt:
    # I don't _think_ this is necessary, but better safe than sorry!
    dd.kill()
    raise


def finalize(args):
  if args.no_wifi:
    print('no-wifi flag set - not setting up wifi')
  else:
    if not args.ssid or not args.wifi_password:
      print('If `no-wifi` is not set, you must provide `ssid` and `wifi-password`')
      exit(1)

  # TODO - set hostname: https://techexplorations.com/guides/rpi/begin/raspberry-pi-hostname/
  disk_number_and_info = _find_disk_number_and_info()
  Path('/Volumes/boot/ssh').touch()
  if not args.no_wifi:
    with open('/Volumes/boot/wpa_supplicant.conf', 'w') as f:
      f.write(f'''ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
  update_config=1
  country=US

  network={{
      ssid="{args.ssid}"
      psk={_wpa_passphrase(args.ssid, args.wifi_password)}
      key_mgmt=WPA-PSK
  }}
  ''')
  # Note it is intentional that there are no quotes around psk

  # Raspberry Pi OS no longer sets `raspberry` as the default password
  # https://www.raspberrypi.com/news/raspberry-pi-bullseye-update-april-2022/
  #
  # Note the below required OpenSSL version >=1.1 -
  # https://ubuntu101.co.za/osx-and-macos/homebrew-missing-sha512sum-sha256sum-macos/
  encoded_password = check_output(['openssl', 'passwd', '-6', args.password], encoding='UTF-8').strip()
  with open('/Volumes/boot/userconf', 'w') as f:
    f.write(f'pi:{encoded_password}')
  print('Wrote encoded password to disk')

  # TODO - consider writing to cmdline.txt here, too (see `kube_setup/1.sh`)
  # Why am I not doing that immediately? Because it looks like there are some first-time options
  # that I don't want to mess with - initial image, unbooted, reads:
  # `console=serial0,115200 console=tty1 root=PARTUUID=<id> rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspi-config/init_resize.sh`

  Popen(['diskutil', 'eject', f'/dev/rdisk{disk_number_and_info[0]}'])
  time.sleep(1)
  print('Finished writing, disk ejected')


# https://stackoverflow.com/questions/46502224/python-wpa-passphrase-linux-binary-implementation-generates-only-part-of-the-p
def _wpa_passphrase(ssid, pswd):
  dk = hashlib.pbkdf2_hmac(
      'sha1', str.encode(pswd),
      str.encode(ssid), 4096, 32
  )
  return binascii.hexlify(dk).decode("UTF-8")


if __name__ == '__main__':

  # Yes, this violates EAFP - but I don't want to muck around with parsing "Permission denied"
  # messages out from shell responses
  if not os.environ.get("SUDO_UID") and os.geteuid() != 0:
    raise PermissionError("You need to run this script with sudo or as root.")

  parser = argparse.ArgumentParser()
  subparsers = parser.add_subparsers(help='Call `create` then `finalize`')

  create_parser = subparsers.add_parser('create', help='Create the initial image')
  create_parser.add_argument('--image-file')
  create_parser.add_argument('--image-type',
                             choices = IMAGE_TYPES.keys(),
                             default = 'lite64',
                             help='If choosing to download the image from the internet ' +\
                             '(rather than provide it locally), select which image type to download. ' +\
                             'Ignored if an `--image-file` is provided')
  create_parser.set_defaults(func=create)

  finalize_parser = subparsers.add_parser('finalize', help='Finalize a created image')
  finalize_parser.add_argument('--ssid')
  finalize_parser.add_argument('--wifi-password')
  finalize_parser.add_argument('--no-wifi', action='store_true', default=False)
  finalize_parser.add_argument('--password', required=True)
  finalize_parser.set_defaults(func=finalize)

  args = parser.parse_args()
  if 'func' not in args.__dict__:
    print(f'Usage: `sudo ./setup_image.py {[key for key in subparsers.choices.keys()]} <options>')
    exit(1)
  args.func(args)
