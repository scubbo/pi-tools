#!/usr/bin/env python3

"""
Client for calling the server defined at hass-backup-sync-server.py
"""

import socket
import sys

HOST = 'localhost'
PORT = 9999

USAGE_STRING = f'Usage: {sys.argv[0]} sync-backup arg1=val1 arg2=val2 ...'

if __name__ == '__main__':
  if len(sys.argv) == 1:
    print(USAGE_STRING)
    sys.exit(1)
  if sys.argv[1] != 'sync-backup':
    print(USAGE_STRING)
    sys.exit(1)
  with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.connect((HOST, PORT))
    sock.sendall(bytes(' '.join(sys.argv[1:]) + '\n', 'utf-8'))
