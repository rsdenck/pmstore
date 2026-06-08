# E cada template virar algo próximo de:

#!/usr/bin/env bash

source <(curl -fsSL https://pmoflow.pro/lib/pmstack.func)

APP="Hazuh"
APP_CATEGORY="Security"
APP_OS="Rocky"
APP_VERSION="9"

var_cpu=2
var_ram=4096
var_disk=16

start
build_container
install_hazuh
finish

Ficaria muito mais próximo da arquitetura dos Community Scripts, mas com identidade PMStore/PMStack e espaço para evoluir depois para:

PMTUI
Wizard avançado
Marketplace
Analytics
Templates Enterprise
PMStore API
Deploy em cluster Proxmox
PBS integration
Vault integration
Hardening profiles
Observability stack

Tudo sem duplicar código em cada template.
