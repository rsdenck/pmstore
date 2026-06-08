#!/usr/bin/env bash
set -euo pipefail

APP="Osquery"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;osquery;security;monitoring"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Osquery..."
pct exec "$CTID" -- bash -c '
cd /tmp
OSQUERY_VER="5.23.0"
curl -fsSL "https://github.com/osquery/osquery/releases/download/${OSQUERY_VER}/osquery-${OSQUERY_VER}-1.linux.x86_64.rpm" -o osquery.rpm 2>/dev/null
dnf install -y -q /tmp/osquery.rpm 2>/dev/null
rm -f /tmp/osquery.rpm
systemctl enable osqueryd 2>/dev/null
' 2>/dev/null
msg_ok "Osquery installed"

finish
