#!/usr/bin/env python3

import argparse
import hashlib
import json
import requests

from pathlib import Path

def main(args):
  r = requests.get('http://localhost:3000/api/search?query=&', auth=(args.user, args.password))
  output = json.dumps([_get_json_for_uid(dash['uid'], args.user, args.password) for dash in r.json()])

  hash_val = _hash_string(output)
  main_path = Path(args.output_location)
  hash_path = main_path.with_suffix('.hash')
  if hash_path.exists():
    existing_hash = hash_path.read_bytes()
  else:
    existing_hash = None

  if hash_val != existing_hash:
    main_path.write_text(output)
    hash_path.write_bytes(hash_val)
    print('Persisted new dashboard definition')
  else:
    print('No update')


def _get_json_for_uid(uid, username, password):
  return requests.get(f'http://localhost:3000/api/dashboards/uid/{uid}', auth=(username, password)).json()['dashboard']


def _hash_string(s):
  hasher = hashlib.sha256()
  hasher.update(bytes(s, 'utf-8'))
  return hasher.digest()


if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--user', required=True)
  parser.add_argument('--password', required=True)
  parser.add_argument('--output-location', required=True)
  main(parser.parse_args())
