#!/usr/bin/env bash
set -euo pipefail

APP="UptimeKuma"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;uptime-kuma;monitoring;uptime"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden
install_build_deps

msg_info "Installing Uptime Kuma..."
pct exec "$CTID" -- bash -c '
dnf install -y -q nodejs npm 2>/dev/null
git clone --depth 1 https://github.com/louislam/uptime-kuma.git /opt/uptime-kuma 2>/dev/null
cd /opt/uptime-kuma
npm run setup 2>/dev/null

cat > /etc/systemd/system/uptime-kuma.service << \EOF
[Unit]
Description=Uptime Kuma
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/uptime-kuma
ExecStart=/usr/bin/node server/server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable uptime-kuma 2>/dev/null
' 2>/dev/null
msg_ok "Uptime Kuma installed"

finish
