#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: wjzijderveld
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/glance-apps/glance-vault

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  build-essential \
  python3
msg_ok "Installed Dependencies"

NODE_VERSION="22" setup_nodejs

fetch_and_deploy_gh_branch "glance-vault" "glance-apps/glance-vault" "main"

msg_info "Building GLANCEvault"
cd /opt/glance-vault
$STD npm ci
$STD npm run build
msg_ok "Built GLANCEvault"

msg_info "Setting up Application"
mkdir -p /opt/glance-vault/data
var_allowed_origins="${var_allowed_origins:-*}"
GLANCEVAULT_TOKEN=$(openssl rand -hex 32)
cat <<EOF >/opt/glance-vault/.env
GLANCEVAULT_DEVICE_TOKEN=${GLANCEVAULT_TOKEN}
GLANCEVAULT_PORT=8080
GLANCEVAULT_STORAGE_PATH=/opt/glance-vault/data/glancevault.db
GLANCEVAULT_ALLOWED_ORIGINS=${var_allowed_origins}
EOF
msg_ok "Set up Application"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/glance-vault.service
[Unit]
Description=GLANCEvault Sync Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/glance-vault
EnvironmentFile=/opt/glance-vault/.env
ExecStart=/usr/bin/node /opt/glance-vault/dist/index.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now glance-vault
msg_ok "Created Service"

echo -e "${INFO}${YW} Device token for your GLANCE apps (also in /opt/glance-vault/.env):${CL}"
echo -e "${TAB}${BGN}${GLANCEVAULT_TOKEN}${CL}"
echo -e "${INFO}${YW} Allowed browser origins: ${var_allowed_origins}${CL}"

motd_ssh
customize
cleanup_lxc
