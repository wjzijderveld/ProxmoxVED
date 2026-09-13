#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: wjzijderveld
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/krelltunez/lastGLANCE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y nginx
msg_ok "Installed Dependencies"

NODE_VERSION="20" setup_nodejs

fetch_and_deploy_gh_release "lastglance" "krelltunez/lastGLANCE" "tarball"

msg_info "Building lastGLANCE"
cd /opt/lastglance
$STD npm install
$STD npm run build
msg_ok "Built lastGLANCE"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/lastglance-proxy.service
[Unit]
Description=lastGLANCE WebDAV Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node /opt/lastglance/server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now lastglance-proxy
msg_ok "Created Service"

msg_info "Configuring Nginx"
cat <<EOF >/etc/nginx/sites-available/lastglance
server {
  listen 6768;
  listen [::]:6768;
  server_name _;
  root /opt/lastglance/dist;
  index index.html;

  location = /sw.js {
    expires off;
    add_header Cache-Control "no-cache, no-store, must-revalidate";
  }

  location ~* \.(?:js|css|woff2?|png|jpg|jpeg|gif|svg|ico|webp)\$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  location /api/ {
    proxy_pass http://127.0.0.1:3001;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_read_timeout 60s;
    proxy_send_timeout 60s;
    client_max_body_size 50m;
  }

  location / {
    try_files \$uri \$uri/ /index.html;
  }
}
EOF
ln -sf /etc/nginx/sites-available/lastglance /etc/nginx/sites-enabled/lastglance
rm -f /etc/nginx/sites-enabled/default
$STD nginx -t
systemctl reload nginx
msg_ok "Configured Nginx"

motd_ssh
customize
cleanup_lxc
