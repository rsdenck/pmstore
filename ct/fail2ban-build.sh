#!/usr/bin/env bash
set -euo pipefail

APP="Fail2ban"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;fail2ban;security;ids;bruteforce"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Fail2ban..."
pct exec "$CTID" -- bash -c '
dnf install -y -q epel-release 2>/dev/null
dnf install -y -q fail2ban 2>/dev/null
systemctl enable fail2ban 2>/dev/null
' 2>/dev/null
msg_ok "Fail2ban installed"

finish
