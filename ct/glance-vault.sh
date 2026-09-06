#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: wjzijderveld
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/glance-apps/glance-vault

APP="glance-vault"
var_tags="${var_tags:-sync;backend;privacy}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified
var_unprivileged="${var_unprivileged:-1}"

# Browser origins allowed to call the vault (CORS).
export var_allowed_origins="${var_allowed_origins:-*}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/glance-vault ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_branch "glance-vault" "glance-apps/glance-vault" "main"; then
    msg_info "Stopping Service"
    systemctl stop glance-vault
    msg_ok "Stopped Service"

    create_backup /opt/glance-vault/.env /opt/glance-vault/data

    CLEAN_INSTALL=1 fetch_and_deploy_gh_branch "glance-vault" "glance-apps/glance-vault" "main"

    NODE_VERSION="22" setup_nodejs

    restore_backup

    msg_info "Building GLANCEvault"
    cd /opt/glance-vault
    $STD npm ci
    $STD npm run build
    msg_ok "Built GLANCEvault"

    msg_info "Starting Service"
    systemctl start glance-vault
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080/healthz${CL}"
