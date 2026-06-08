#!/usr/bin/env bash
set -euo pipefail

APP="Certmate"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;certmate;ssl;certificate;acme"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Certmate SSL manager..."
pct exec "$CTID" -- bash -c '
dnf install -y -q git python3 python3-pip 2>/dev/null
useradd --system --shell /bin/false --home-dir /opt/certmate --create-home certmate 2>/dev/null || true
git clone https://github.com/fabriziosalmi/certmate.git /opt/certmate 2>/dev/null
cd /opt/certmate
python3 -m venv venv 2>/dev/null
./venv/bin/pip install -q -r requirements.txt 2>/dev/null
mkdir -p certificates data 2>/dev/null
chown -R certmate:certmate /opt/certmate 2>/dev/null
cat > /etc/systemd/system/certmate.service << "SVC"
[Unit]
Description=Certmate SSL Certificate Manager
After=network.target
[Service]
Type=simple
User=certmate
WorkingDirectory=/opt/certmate
ExecStart=/opt/certmate/venv/bin/python app.py
Restart=on-failure
[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload 2>/dev/null
systemctl enable certmate 2>/dev/null
' 2>/dev/null
msg_ok "Certmate installed"

finish
