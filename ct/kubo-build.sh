#!/usr/bin/env bash
set -euo pipefail

APP="Kubo"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;kubo;ipfs;p2p;storage"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Kubo (IPFS)..."
pct exec "$CTID" -- bash -c '
cd /tmp
curl -fsSL https://dist.ipfs.tech/kubo/v0.42.0/kubo_v0.42.0_linux-amd64.tar.gz -o kubo.tar.gz 2>/dev/null
tar -xzf kubo.tar.gz
cd kubo
bash install.sh 2>/dev/null
cd /tmp
rm -rf kubo kubo.tar.gz
ipfs init 2>/dev/null
cat > /etc/systemd/system/ipfs.service << "SVC"
[Unit]
Description=IPFS Kubo Daemon
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ipfs daemon --enable-gc
Restart=on-failure
[Install]
WantedBy=multi-user.target
SVC
systemctl enable ipfs 2>/dev/null
' 2>/dev/null
msg_ok "Kubo (IPFS) installed"

finish
