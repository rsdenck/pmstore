#!/usr/bin/env bash
set -euo pipefail

APP="PiHole"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;pihole;dns;adblock;networking"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden
install_build_deps

msg_info "Installing Pi-hole..."
pct exec "$CTID" -- bash -c '
curl -fsSL https://install.pi-hole.net -o /tmp/basic-install.sh 2>/dev/null
bash /tmp/basic-install.sh --unattended 2>/dev/null
rm -f /tmp/basic-install.sh
' 2>/dev/null
msg_ok "Pi-hole installed"

finish
