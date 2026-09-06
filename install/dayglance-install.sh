#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: wjzijderveld
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/krelltunez/dayGLANCE

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

fetch_and_deploy_gh_release "dayglance" "krelltunez/dayGLANCE" "tarball"

msg_info "Building dayGLANCE"
cd /opt/dayglance
export NODE_OPTIONS="--max-old-space-size=4096"
ELECTRON_SKIP_BINARY_DOWNLOAD=1 $STD npm install
$STD npm run build
unset NODE_OPTIONS
msg_ok "Built dayGLANCE"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/dayglance-proxy.service
[Unit]
Description=dayGLANCE WebDAV/Calendar Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node /opt/dayglance/docker/proxy-server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now dayglance-proxy
msg_ok "Created Service"

msg_info "Configuring Nginx"
cat <<EOF >/etc/nginx/sites-available/dayglance
server {
  listen 6767;
  server_name _;
  root /opt/dayglance/dist;
  index index.html;

  gzip on;
  gzip_vary on;
  gzip_min_length 1024;
  gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript application/manifest+json;

  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-XSS-Protection "1; mode=block" always;
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src *; font-src 'self' data:; worker-src 'self' blob:; manifest-src 'self';" always;

  location = /sw.js {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
  }

  location = /manifest.webmanifest {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
    add_header Content-Type "application/manifest+json";
  }

  location = /service-worker.js {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  location /api/ {
    proxy_pass http://127.0.0.1:3001;
    proxy_pass_request_body on;
    proxy_pass_request_headers on;
    proxy_read_timeout 60s;
    proxy_connect_timeout 30s;
  }

  location / {
    try_files \$uri \$uri/ /index.html;
  }
}
EOF
ln -sf /etc/nginx/sites-available/dayglance /etc/nginx/sites-enabled/dayglance
rm -f /etc/nginx/sites-enabled/default
$STD nginx -t
systemctl reload nginx
msg_ok "Configured Nginx"

motd_ssh
customize
cleanup_lxc
