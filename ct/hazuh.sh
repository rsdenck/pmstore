#!/usr/bin/env bash
# PMStore — HAZUH (Wazuh SOC Appliance) v4 — Deploy Wizard
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/hazuh.sh
# Usage:
#   Interactive (form):             bash hazuh.sh
#   Headless env vars:              bash -c "$(curl -fsSL https://pmoflow.pro/hazuh.sh)"
#     export IP="192.168.130.10/24" GW="192.168.130.1" DNS="8.8.8.8"
#     export HOSTNAME="HAZUH01" SSH_PORT="22" SSH_ENABLED="true"
#     export var_cpu=2 var_ram=4096 var_disk=16
#
# The PMTUI wizard handles everything: config form, pct create, provisioning.

# ── Load PMStack framework ──
if [ -f "$(dirname "$0")/../core/pmstack.func" ]; then
  source "$(dirname "$0")/../core/pmstack.func"
else
  source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/core/pmstack.func)
fi

# ── Appliance definition (exported for PMTUI) ──
export APPLIANCE="hazuh"
export TAGS="pmstack;rsdenck"
export TEMPLATE="${TEMPLATE:-local:vztmpl/rockylinux-9-default_20240912_amd64.tar.xz}"
export STORAGE="${STORAGE:-local-lvm}"
export BRIDGE="${BRIDGE:-vmbr0}"

# ── Resource defaults (env overridable) ──
export CTID="${CTID:-$(next_ctid)}"
export VAR_CPU="${var_cpu:-2}"
export VAR_RAM="${var_ram:-4096}"
export VAR_DISK="${var_disk:-16}"

# ── Network config (for headless/batch mode) ──
if [ -n "${IP:-}" ]; then
  # Parse IP/CIDR: "192.168.130.10/24" → IP=192.168.130.10 NETMASK=24
  export PMTUI_IP="${IP%%/*}"
  if [[ "$IP" == */* ]]; then
    export PMTUI_NETMASK="${IP#*/}"
  fi
  export PMTUI_IP_MODE="static"
  export PMTUI_GATEWAY="${GW:-}"
  export PMTUI_DNS="${DNS:-8.8.8.8}"
  export PMTUI_HOSTNAME="${HOSTNAME:-HAZUH}"
  export PMTUI_SSH_PORT="${SSH_PORT:-22}"
  export PMTUI_SSH_ENABLED="${SSH_ENABLED:-true}"
  HEADLESS=1
else
  HEADLESS=0
fi

# ── Error handling ──
check_root
check_pct

# ── Deploy wizard ──
download_pmtui_wizard

if [ "$HEADLESS" = 1 ]; then
  "$PMTUI_BIN" --deploy --text
else
  "$PMTUI_BIN" --deploy
fi
