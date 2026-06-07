#!/usr/bin/env bash
set -Eeuo pipefail

# PMStore - Proxmox VE Container Deployer
# Usage: var_cpu="2" var_ram="2048" var_disk="8" bash -c "$(curl -fsSL https://pmoflow.pro/proxmox-ve.sh)"

PMSTACK="\e[96mPMSTACK\e[39m"
RSDENCK="\e[92mrsdenck\e[39m"
PMSTORE="\e[93mPMStore\e[39m"

header_info() {
  clear
  echo -e ""
  echo -e "========================================"
  echo -e "  $PMSTACK CONSOLE"
  echo -e "  $RSDENCK"
  echo -e "========================================"
  echo -e "  $PMSTORE - Container Deployer"
  echo -e "========================================"
  echo -e ""
}

set -Eeuo pipefail
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR

error_exit() {
  trap - ERR
  local REASON="\e[97m${1:-Unknown failure}\e[39m"
  local FLAG="\e[91m[ERROR]\e[39m \e[93m$EXIT@$LINE"
  echo -e "$FLAG $REASON" >&2
  exit $EXIT
}

cleanup_ctid() {
  if pct status $CTID &>/dev/null; then
    pct stop $CTID 2>/dev/null || true
    pct destroy $CTID 2>/dev/null || true
  fi
}

[[ $EUID -eq 0 ]] || die "Must run as root"
command -v pct &>/dev/null || die "pct not found"

var_cpu=${var_cpu:-1}
var_ram=${var_ram:-2048}
var_disk=${var_disk:-8}

check_ct_script() {
  local name="$1"
  local path="/opt/lxchub/ct/${name}.sh"
  if [[ -f "$path" ]]; then
    return 0
  fi
  # Try fetching from GitHub
  local url="https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/${name}.sh"
  if curl -fsSL -o /dev/null --max-time 5 "$url" 2>/dev/null; then
    return 0
  fi
  return 1
}

run_ct_script() {
  local name="$1"
  local path="/opt/lxchub/ct/${name}.sh"
  if [[ -f "$path" ]]; then
    CTID=${CTID:-$(pvesh get /cluster/nextid 2>/dev/null)} \
    var_cpu="$var_cpu" \
    var_ram="$var_ram" \
    var_disk="$var_disk" \
    bash "$path"
  else
    local url="https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/${name}.sh"
    curl -fsSL "$url" | CTID=${CTID:-$(pvesh get /cluster/nextid 2>/dev/null)} \
      var_cpu="$var_cpu" \
      var_ram="$var_ram" \
      var_disk="$var_disk" \
      bash
  fi
}

header_info

AVAILABLE_APPLIANCES=()

while read -r f; do
  name=$(basename "$f" .sh)
  AVAILABLE_APPLIANCES+=("$name" "Wazuh component" "OFF")
done < <(ls /opt/lxchub/ct/*.sh 2>/dev/null | grep -v pmtui || true)

if [[ ${#AVAILABLE_APPLIANCES[@]} -eq 0 ]]; then
  echo -e "$RSDENCK - No appliances found locally"
  echo -e ""
  echo -e "Available via PMStore:"
  echo -e "  - hazuh"
  echo -e ""
  read -r -p "Appliance to deploy: " APPLIANCE
  if check_ct_script "$APPLIANCE"; then
    run_ct_script "$APPLIANCE"
  else
    die "Appliance '$APPLIANCE' not found in PMStore"
  fi
else
  MSG_MAX_LENGTH=0
  MENU_ITEMS=()
  for ((i=0; i<${#AVAILABLE_APPLIANCES[@]}; i+=3)); do
    ITEM="${AVAILABLE_APPLIANCES[$i]}"
    OFFSET=2
    ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
    MENU_ITEMS+=("$ITEM" "${AVAILABLE_APPLIANCES[$i+1]}" "${AVAILABLE_APPLIANCES[$i+2]}")
  done

  if command -v whiptail &>/dev/null; then
    APPLIANCE=$(whiptail --backtitle "PMStore by rsdenck" \
      --title "PMSTACK CONSOLE" \
      --radiolist "\nSelect an appliance to deploy:\n" \
      16 $((MSG_MAX_LENGTH + 58)) 6 \
      "${MENU_ITEMS[@]}" \
      3>&1 1>&2 2>&3 | tr -d '"') || die "No selection"
    [[ -z "$APPLIANCE" ]] && die "No appliance selected"
  else
    echo -e ""
    echo -e "Available appliances:"
    for ((i=0; i<${#AVAILABLE_APPLIANCES[@]}; i+=3)); do
      echo -e "  $(($i/3+1))) ${AVAILABLE_APPLIANCES[$i]}"
    done
    echo -e ""
    read -r -p "Choice [1-$((${#AVAILABLE_APPLIANCES[@]}/3))]: " choice
    idx=$((choice*3-3))
    APPLIANCE="${AVAILABLE_APPLIANCES[$idx]}"
  fi

  echo -e ""
  echo -e "Deploying: $APPLIANCE"
  echo -e "CPU: $var_cpu | RAM: ${var_ram}MB | Disk: ${var_disk}GB"
  echo -e ""

  run_ct_script "$APPLIANCE"
fi
