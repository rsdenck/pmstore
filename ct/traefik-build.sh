#!/usr/bin/env bash
set -euo pipefail

APP="Traefik"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;traefik;proxy;reverse-proxy;networking"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden
install_build_deps

msg_info "Installing Traefik..."
pct exec "$CTID" -- bash -c '
TRAEFIK_VERSION=$(curl -fsSL https://api.github.com/repos/traefik/traefik/releases/latest 2>/dev/null | grep -oP "tag_name\": \"v\K[^\"]+")
curl -fsSL "https://github.com/traefik/traefik/releases/download/v${TRAEFIK_VERSION}/traefik_v${TRAEFIK_VERSION}_linux_amd64.tar.gz" -o /tmp/traefik.tar.gz 2>/dev/null
tar xzf /tmp/traefik.tar.gz -C /usr/local/bin/ 2>/dev/null
rm -f /tmp/traefik.tar.gz
chmod +x /usr/local/bin/traefik 2>/dev/null
mkdir -p /etc/traefik /var/log/traefik 2>/dev/null

cat > /etc/systemd/system/traefik.service << \EOF
[Unit]
Description=Traefik Reverse Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable traefik 2>/dev/null
' 2>/dev/null
msg_ok "Traefik installed"

finish
