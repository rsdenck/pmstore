#!/usr/bin/env bash
set -euo pipefail

APP="Beszel"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;beszel;monitoring;metrics"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden
install_build_deps

msg_info "Installing Beszel..."
pct exec "$CTID" -- bash -c '
curl -fsSL https://raw.githubusercontent.com/henrygd/beszel/main/install.sh -o /tmp/install.sh 2>/dev/null
bash /tmp/install.sh 2>/dev/null
rm -f /tmp/install.sh
systemctl enable beszel 2>/dev/null || true
' 2>/dev/null
msg_ok "Beszel installed"

finish
