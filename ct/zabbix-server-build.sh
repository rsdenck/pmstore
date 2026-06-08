#!/usr/bin/env bash
set -euo pipefail

APP="Zabbix-Server"
APP_VERSION="9"
APP_OS="rocky"
TAGS="pmstack;rsdenck;zabbix"

VM_STORAGE="${VM_STORAGE:-local-lvm}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"

source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/lib/pmstack.func)

start
build_container
install_pmtui
soc_harden

msg_info "Installing Zabbix server..."
pct exec "$CTID" -- bash -c '
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rocky/9/x86_64/zabbix-release-7.0-5.el9.noarch.rpm 2>/dev/null
dnf install -y -q zabbix-server-mysql zabbix-web-mysql zabbix-agent 2>/dev/null
systemctl enable zabbix-server zabbix-agent httpd php-fpm 2>/dev/null
' 2>/dev/null
msg_ok "Zabbix server installed"

finish
