#!/usr/bin/env bash
set -euo pipefail

APP="AdGuardHome"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;adguard;dns;adblock;networking"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden
install_build_deps

msg_info "Installing AdGuardHome..."
pct exec "$CTID" -- bash -c '
cd /opt
curl -fsSL "https://static.adtidy.org/adguardhome/release/AdGuardHome_linux_amd64.tar.gz" -o adguard.tar.gz 2>/dev/null
tar xzf adguard.tar.gz 2>/dev/null
rm -f adguard.tar.gz
ln -s /opt/AdGuardHome/AdGuardHome /usr/local/bin/adguard 2>/dev/null

cat > /etc/systemd/system/adguard.service << \EOF
[Unit]
Description=AdGuard Home
After=network.target

[Service]
Type=simple
ExecStart=/opt/AdGuardHome/AdGuardHome -s run
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable adguard 2>/dev/null
' 2>/dev/null
msg_ok "AdGuardHome installed"

finish
