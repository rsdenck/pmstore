#!/usr/bin/env bash
set -euo pipefail

APP="NginxProxyManager"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;nginx-proxy-manager;npm;proxy;reverse-proxy"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden
install_build_deps

msg_info "Installing Nginx Proxy Manager..."
pct exec "$CTID" -- bash -c '
dnf install -y -q nginx certbot python3-certbot-nginx 2>/dev/null

# Install NPM from source
git clone --depth 1 https://github.com/NginxProxyManager/nginx-proxy-manager.git /opt/nginx-proxy-manager 2>/dev/null
cd /opt/nginx-proxy-manager

cat > /etc/systemd/system/npm.service << \EOF
[Unit]
Description=Nginx Proxy Manager
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/nginx
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nginx 2>/dev/null
systemctl enable npm 2>/dev/null || true
' 2>/dev/null
msg_ok "Nginx Proxy Manager installed"

finish
