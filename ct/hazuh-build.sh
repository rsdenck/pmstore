#!/usr/bin/env bash
# PMStack Template Builder — HAZUH (Wazuh SOC Appliance) v4
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/hazuh-build.sh
# Usage: bash hazuh-build.sh

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

APP="Hazuh"
APP_CATEGORY="Security"
APP_OS="Rocky"
APP_VERSION="9"

var_cpu=2
var_ram=4096
var_disk=20

start

build_container

install_pmtui

soc_harden

msg_info "Installing Wazuh manager..."
CTID="${CTID}"
pct exec "$CTID" -- bash -c '
cat > /etc/yum.repos.d/wazuh.repo << "REPO"
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
REPO
dnf install -y -q wazuh-manager 2>/dev/null
systemctl enable wazuh-manager 2>/dev/null
' 2>/dev/null

msg_ok "Wazuh manager installed"

finish
