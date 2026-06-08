#!/usr/bin/env bash
set -euo pipefail

APP="Crowdsec"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;crowdsec;security;ids;waf"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Crowdsec IPS/WAF..."
pct exec "$CTID" -- bash -c '
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | bash 2>/dev/null
dnf install -y -q crowdsec 2>/dev/null
systemctl enable crowdsec 2>/dev/null
' 2>/dev/null
msg_ok "Crowdsec installed"

finish
