#!/usr/bin/env python3

import argparse
import os.path
import pathlib
import requests
import sys

import logging
log = logging.getLogger(__name__)
formatter = logging.Formatter(fmt='%(asctime)s\t%(name)-12s\t%(levelname)-8s\t%(message)s')

streamHandler = logging.StreamHandler()
from logging.handlers import RotatingFileHandler
logging_dir = pathlib.Path.home().joinpath('log/scubbo-cf-dyndns/')
if not logging_dir.exists():
    logging_dir.mkdir(parents=True)
fileHandler = RotatingFileHandler(logging_dir.joinpath('log.log'), maxBytes=2000000, backupCount=2)
streamHandler.setFormatter(formatter)
fileHandler.setFormatter(formatter)
log.addHandler(streamHandler)
log.addHandler(fileHandler)
log.setLevel(logging.INFO)

# https://api.cloudflare.com/
BASE_URL = 'https://api.cloudflare.com/client/v4/'


def _find_zone_for_name(session, name):
    zones = session.get(BASE_URL + 'zones').json()['result']
    for zone in zones:
        if name.endswith(zone['name']):
            return zone
    log.error(f'Unable to find zone for name {name}')
    exit(1)


def _find_current_dns_record(session, name, zone_id):
    dns_records_for_zone = session.get(BASE_URL + f'zones/{zone_id}/dns_records').json()['result']
    for dns_record in dns_records_for_zone:
      if dns_record['name'] == name:
        return dns_record
    # It's fine if we find no existing DNS record - that means we're setting up a new record
    return None


def _update_dns(session, zone_id, record, ip):
    update_response = session.put(
        BASE_URL + f'zones/{zone_id}/dns_records/{record["id"]}',
        json={
            'type': record['type'],
            'name': record['name'],
            'content': ip,
            'ttl': 1
        })


def main(args):
    token_path = pathlib.Path(args.token_file_location)
    if not token_path.exists():
        log.error(f'Token path {token_path} does not exist')
        exit(1)

    cf_session = requests.Session()
    cf_session.headers.update({
      'Authorization': f'Bearer {token_path.read_text().strip()}',
      'Content-Type': 'application/json'
    })

    zone_id = _find_zone_for_name(cf_session, args.dns_name)['id']
    log.debug(f'Found {zone_id} for {args.dns_name}')

    current_dns_record = _find_current_dns_record(cf_session, args.dns_name, zone_id)
    current_dns_ip = current_dns_record['content'] if current_dns_record else '<NOT SET>'
    actual_ip = requests.get('http://ifconfig.io', headers={'User-Agent': 'curl/7.76.0'}).text.strip()

    if current_dns_ip == actual_ip:
      log.info(f'IPs match ({current_dns_ip}) - doing nothing')
      return

    log.info(f'Current DNS IP is {current_dns_ip}, actual IP is {actual_ip} - updating')
    if current_dns_record: # That is, if a record already exists
        _update_dns(cf_session, zone_id, current_dns_record, actual_ip)
    else:
        log.error('This script does not currently support creating a fresh record')
        exit(1)


if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--dns-name', required=True, help='The DNS Name to update. E.g. `example.org`')
  parser.add_argument('--token-file-location', required=True, help='Location of a file that holds the Cloudflare API Token')
  main(parser.parse_args())
