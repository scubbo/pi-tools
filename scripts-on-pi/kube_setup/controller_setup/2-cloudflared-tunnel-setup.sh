#!/bin/bash

# This is a separate script because it requires interactive setup
#
# Doc ref: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/run-tunnel/as-a-service/linux/

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

apt install -y jq

if [[ ! -f /usr/bin/cloudflared ]]; then
  latestVersion=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases | jq -r '.[] .tag_name' | sort -V | tail -n1)
  wget -O /usr/bin/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/download/$latestVersion/cloudflared-linux-arm
  chmod +x /usr/bin/cloudflared
fi

# If you need to create the creds from scratch, use:
# `/usr/bin/cloudflared login`
# Move the `cert.pem` to appropriate location
# `/usr/bin/cloudflared tunnel create avril`
ln -s /mnt/BERTHA/cloudflared_tunnel_config /root/.cloudflared

/usr/bin/cloudflared service install
systemctl start cloudflared

# After you update the tunnel,
# validate with `cloudflared tunnel ingress validate`
# then restart with `cp /root/.cloudflared/config.yml /etc/cloudflared/config.yml && systemctl restart cloudflared`
#
# It's also necessary to create a CNAME DNS record in Cloudflare DNS pointing to
# `<tunnel UUID>.cfargotunnel.com` - can be done with `cloudflared tunnel route dns avril <hostname>`

