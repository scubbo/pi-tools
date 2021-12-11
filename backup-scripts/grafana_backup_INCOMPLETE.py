#!/usr/bin/env python3

import argparse
import requests

def main(args):
  r = requests.get('http://localhost:3000/api/search?query=&', auth=(args.user, args.password))
  print(r.json())

if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--user', required=True)
  parser.add_argument('--password', required=True)
  main(parser.parse_args())
