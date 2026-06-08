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
install_zabbix_server
install_pmtui
soc_harden
finish
