#!/usr/bin/env bash
# PMStore — Proxmox VE Container Deployer
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/proxmox-ve.sh
# Usage: var_cpu="2" var_ram="2048" var_disk="8" bash -c "$(curl -fsSL https://pmoflow.pro/proxmox-ve.sh)"

# ── Load PMStack framework ──
if [ -f "$(dirname "$0")/core/pmstack.func" ]; then
  source "$(dirname "$0")/core/pmstack.func"
else
  source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/core/pmstack.func)
fi

# ── Defaults ──
var_cpu=${var_cpu:-1}
var_ram=${var_ram:-2048}
var_disk=${var_disk:-8}

check_root
check_pct
catch_errors

# ── Header ──
header_info
echo -e "  ${C_YELLOW}PMStore${C_RESET} - Container Deployer"
echo -e "========================================"
echo ""

# ── Find available appliances ──
APPLIANCES=()
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Try local ct/ directory first
if [ -d "${SCRIPT_DIR}/ct" ]; then
  for f in "${SCRIPT_DIR}/ct/"*.sh; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .sh)
    APPLIANCES+=("$name")
  done
fi

# If none locally, fetch remote list
if [ ${#APPLIANCES[@]} -eq 0 ]; then
  msg_info "No local appliances found. Checking PMStore..."
  APPLIANCES=("hazuh")
fi

# ── Appliance selection ──
SELECTED=""
if [ ${#APPLIANCES[@]} -eq 1 ]; then
  SELECTED="${APPLIANCES[0]}"
elif command -v whiptail &>/dev/null; then
  MENU=()
  for a in "${APPLIANCES[@]}"; do
    MENU+=("$a" "" OFF)
  done
  SELECTED=$(whiptail --backtitle "PMStore by rsdenck" \
    --title "PMSTACK CONSOLE" \
    --radiolist "Select appliance to deploy:\n" \
    15 50 6 \
    "${MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"') || die "Cancelled"
else
  echo "Available appliances:"
  for i in "${!APPLIANCES[@]}"; do
    echo "  $((i+1))) ${APPLIANCES[$i]}"
  done
  read -r -p "Choice [1-${#APPLIANCES[@]}]: " choice
  SELECTED="${APPLIANCES[$((choice-1))]}"
fi

[ -z "$SELECTED" ] && die "No appliance selected"

# ── Deploy ──
echo ""
msg_info "Deploying ${SELECTED}..."
echo "       CPU: ${var_cpu} | RAM: ${var_ram}MB | Disk: ${var_disk}GB"
echo ""

# Run the appliance script
export CTID var_cpu var_ram var_disk
if [ -f "${SCRIPT_DIR}/ct/${SELECTED}.sh" ]; then
  bash "${SCRIPT_DIR}/ct/${SELECTED}.sh"
else
  bash <(curl -fsSL "https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/${SELECTED}.sh")
fi
