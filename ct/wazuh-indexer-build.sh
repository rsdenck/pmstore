#!/usr/bin/env bash
set -euo pipefail

APP="Wazuh-Indexer"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;wazuh;security"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Wazuh indexer..."
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
dnf install -y -q wazuh-indexer 2>/dev/null
systemctl enable wazuh-indexer 2>/dev/null
' 2>/dev/null
msg_ok "Wazuh indexer installed"

finish
