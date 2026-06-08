#!/usr/bin/env bash
set -euo pipefail

APP="Squid"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;squid;proxy;cache;networking"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Squid proxy..."
pct exec "$CTID" -- bash -c '
dnf install -y -q squid 2>/dev/null
systemctl enable squid 2>/dev/null
' 2>/dev/null
msg_ok "Squid installed"

finish
