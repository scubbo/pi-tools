#!/usr/bin/env python3

import argparse
import boto3
import pathlib
import requests

CACHE_DIR = pathlib.Path.home.joinpath('.dns-update')

def main(args):
  if not CACHE_DIR.exists():
    CACHE_DIR.mkdir(parents=True)
  aws_session = boto3.Session(profile_name=args.profile)

  dns_name = args.dns_name + '.'
  route_53 = aws_session.client('route53')
  zone_id_cache_file = CACHE_DIR.joinpath('.' + dns_name)
  if zone_id_cache_file.exists():
    with zone_id_cache_file.open() as f:
      zone_id = f.read()
  else:
    zone_id = route_53.list_hosted_zones_by_name(DNSName=dns_name)['HostedZones'][0]['Id'].split('/')[-1]
    with zone_id_cache_file.open('w') as f:
      f.write(zone_id)

  zone_ip = [record for record in route_53.list_resource_record_sets(HostedZoneId=zone_id)['ResourceRecordSets'] if record['Type'] == 'A' and record['Name'] == dns_name][0]['ResourceRecords'][0]['Value']
  actual_ip = requests.get('http://ifconfig.io', headers={'User-Agent': 'curl/7.76.0'}).text.strip()
  if zone_ip == actual_ip:
    print(f'Actual IP matches zone IP ({zone_ip}) - doing nothing')
  else:
    print(f'Actual IP {actual_ip} does not match zone IP {zone_ip} - updating')
    print(route_53.change_resource_record_sets(HostedZoneId=zone_id, ChangeBatch={
      'Changes': [{
        'Action': 'UPSERT',
        'ResourceRecordSet': {
          'Name': dns_name,
          'TTL': 1800,
          'Type': 'A',
          'ResourceRecords': [{
            'Value': actual_ip
          }]
        }
      }]
    }))



if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--dns-name', required=True, help='The DNS Name to update. E.g. `example.org`')
  parser.add_argument('--profile', required=True, help='Name of aws profile (in ~/.aws/credentials) to use')
  main(parser.parse_args())