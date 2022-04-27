# This is a separate script because it requires interactive setup

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

useradd -mrs /bin/false cloudflared_tunnel
mkdir -p /home/cloudflared_tunnel/.cloudflared
chown cloudflared_tunnel /home/cloudflared_tunnel/.cloudflared
chgrp cloudflared_tunnel /home/cloudflared_tunnel/.cloudflared

latestVersion=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases | jq -r '.[] .tag_name' | sort -V | tail -n1)
wget -O /usr/bin/cloudflared \
  https://github.com/cloudflare/cloudflared/releases/download/$latestVersion/cloudflared-linux-arm
chmod +x /usr/bin/cloudflared
/usr/bin/cloudflared login # There is some interactivity here!
mv /root/.cloudflared/cert.pem /home/cloudflared_tunnel/.cloudflared
chown cloudflared_tunnel /home/cloudflared_tunnel/.cloudflared/cert.pem
chgrp cloudflared_tunnel /home/cloudflared_tunnel/.cloudflared/cert.pem

cat << EOF > /etc/systemd/system/cloudflared_tunnel.service
[Unit]
Description=Cloudflared Tunnel
After=network.target

[Service]
User=cloudflared_tunnel
Group=cloudflared_tunnel
Type=simple
ExecStart=/usr/bin/cloudflared tunnel --hostname blog.scubbo.org --url http://localhost:8108

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start cloudflared_tunnel
systemctl enable cloudflared_tunnel
