#!/usr/bin/env bash
set -euo pipefail

APP="Haproxy"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;haproxy;proxy;loadbalancer;networking"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing HAProxy..."
pct exec "$CTID" -- bash -c '
dnf install -y -q haproxy 2>/dev/null
systemctl enable haproxy 2>/dev/null
' 2>/dev/null
msg_ok "HAProxy installed"

finish
