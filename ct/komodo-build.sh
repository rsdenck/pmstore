#!/usr/bin/env bash
set -euo pipefail

APP="Komodo"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;komodo;deployment;platform"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Docker + Komodo deployment platform..."
pct exec "$CTID" -- bash -c '
dnf install -y -q dnf-plugins-core 2>/dev/null
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo 2>/dev/null
dnf install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null
systemctl enable docker 2>/dev/null
mkdir -p /opt/komodo 2>/dev/null
curl -fsSL https://raw.githubusercontent.com/moghtech/komodo/main/compose/mongo.compose.yaml -o /opt/komodo/compose.yaml 2>/dev/null
curl -fsSL https://raw.githubusercontent.com/moghtech/komodo/main/compose/compose.env -o /opt/komodo/compose.env 2>/dev/null
systemctl enable docker 2>/dev/null
' 2>/dev/null
msg_ok "Docker + Komodo installed"

finish
