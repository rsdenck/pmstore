#!/usr/bin/env bash
set -euo pipefail

APP="Teleport"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;teleport;ssh;infrastructure;access"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Teleport SSH infrastructure..."
pct exec "$CTID" -- bash -c '
cd /tmp
TELEPORT_VER="v18.8.3"
curl -fsSL "https://cdn.teleport.dev/teleport-${TELEPORT_VER}-linux-amd64-bin.tar.gz" -o teleport.tar.gz 2>/dev/null
tar -xzf teleport.tar.gz 2>/dev/null
cp teleport/teleport teleport/tctl teleport/tsh teleport/teleport-update /usr/local/bin/ 2>/dev/null
cat > /etc/systemd/system/teleport.service << "SVC"
[Unit]
Description=Teleport SSH Infrastructure
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/teleport start
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload 2>/dev/null
systemctl enable teleport 2>/dev/null
rm -rf /tmp/teleport*
' 2>/dev/null
msg_ok "Teleport installed"

finish
