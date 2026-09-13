#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: wjzijderveld
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/krelltunez/lifeGLANCE

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

fetch_and_deploy_gh_release "lifeglance" "krelltunez/lifeGLANCE" "tarball"

msg_info "Building lifeGLANCE"
cd /opt/lifeglance
$STD npm install
$STD npm run build
msg_ok "Built lifeGLANCE"

msg_info "Configuring Nginx"
cat <<EOF >/etc/nginx/sites-available/lifeglance
server {
  listen 6769;
  listen [::]:6769;
  server_name _;
  root /opt/lifeglance/dist;
  index index.html;

  location = /sw.js {
    expires off;
    add_header Cache-Control "no-cache, no-store, must-revalidate";
  }

  location ~* \.(?:js|css|woff2?|png|jpg|jpeg|gif|svg|ico|webp)\$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  location / {
    try_files \$uri \$uri/ /index.html;
  }
}
EOF
ln -sf /etc/nginx/sites-available/lifeglance /etc/nginx/sites-enabled/lifeglance
rm -f /etc/nginx/sites-enabled/default
$STD nginx -t
systemctl enable -q --now nginx
systemctl reload nginx
msg_ok "Configured Nginx"

motd_ssh
customize
cleanup_lxc
