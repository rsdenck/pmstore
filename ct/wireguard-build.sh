#!/usr/bin/env bash
set -euo pipefail

APP="WireGuard"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;wireguard;vpn;networking"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing WireGuard..."
pct exec "$CTID" -- bash -c '
dnf install -y -q epel-release 2>/dev/null
dnf install -y -q wireguard-tools 2>/dev/null
systemctl enable wg-quick@ 2>/dev/null || true
' 2>/dev/null
msg_ok "WireGuard installed"

finish
