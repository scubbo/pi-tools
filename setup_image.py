#!/usr/bin/env python3

import argparse, binascii, hashlib

from pathlib import Path

def main(args):
  # TODO - shell-out to write the image
  Path('/Volumes/boot/ssh').touch()
  with open('/Volumes/boot/wpa_supplicant.conf', 'w') as f:
    f.write(f'''ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={{
    ssid="{args.ssid}"
    psk="{_wpa_passphrase(args.ssid, args.wifi_password)}"
    key_mgmt=WPA-PSK
}}
      ''')

# https://stackoverflow.com/questions/46502224/python-wpa-passphrase-linux-binary-implementation-generates-only-part-of-the-p
def _wpa_passphrase(ssid, pswd):
  dk = hashlib.pbkdf2_hmac(
      'sha1', str.encode(pswd),
      str.encode(ssid), 4096, 32
  )
  return binascii.hexlify(dk).decode("UTF-8")


if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--ssid', required=True)
  parser.add_argument('--wifi-password', required=True)
  main(parser.parse_args())