#!/usr/bin/env python3

import argparse
import enum
import json
import requests


def main(args):
    server = Server(args.server)
    nonce = requests.get(server.url_of_resource('/_synapse/admin/v1/register'))


# Cannot put this "in" the Server - as might seem more natural - because then it
# can't be referenced with
class SupportedMethods(enum.Enum):
    GET = enum.auto(),
    POST = enum.auto()

class Server(object):
    def __init__(self, url: str):
        self.url = url


    def call(self, resource: str, method: SupportedMethods = 'GET'):
        return requests.request(method=str(method), url=self.url_of_resource(resource))


    def url_of_resource(self, resource: str):
        return f'{self.url}{resource}'


if __name__ == '__main__':
    args = argparse.ArgumentParser()
    args.add_argument('--server', type=str, default='matrix.scubbo.org')
    args.add_argument('--shared-secret', type=str, required=True)
    main(args.parse_args())
