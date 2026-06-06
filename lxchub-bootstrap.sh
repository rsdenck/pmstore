#!/usr/bin/env bash
set -Eeuo pipefail

LXCHUB_DIR="/opt/lxchub"
TEMPLATE_STORAGE="local"
VMID=""
HOSTNAME=""
IP=""
GATEWAY=""
DNS="8.8.8.8"
BRIDGE="vmbr0"
SSH_KEY_FILE=""
SSH_PUBKEY=""
DISK_GB="8"
MEMORY_MB="2048"
CORES="1"
APPLIANCE=""
USE_DHCP=0
INTERACTIVE=1
TEMPLATE_IMAGE="debian-12-standard_12.12-1_amd64.tar.zst"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }
usage() {
  cat <<EOF
LXCHub Bootstrap - Deploy LXC containers on Proxmox VE

Usage: $(basename "$0") [options]

Options:
  --id VMID                 Container ID (auto if not set)
  --hostname NAME           Container hostname
  --ip CIDR                 Static IP (e.g. 192.168.1.100/24)
  --gw ADDR                 Gateway (required with --ip)
  --dns ADDR                DNS server (default: 8.8.8.8)
  --dhcp                    Use DHCP instead of static IP
  --bridge IFACE            Network bridge (default: vmbr0)
  --ssh-key FILE            SSH public key file to inject
  --ssh-pubkey "KEY"        SSH public key string to inject
  --disk GB                 Disk size in GB (default: 8)
  --memory MB               Memory in MB (default: 2048)
  --cores N                 vCPUs (default: 1)
  --appliance NAME          Appliance (wazuh, zabbix, etc.)
  --non-interactive         Skip prompts (uses CLI args)
  --ssh-root yes/no         Enable root SSH login (default: yes)
  --help                    Show this help

Examples:
  $(basename "$0") --id 200 --hostname wazuh-ct --appliance wazuh --dhcp
  $(basename "$0") --id 201 --hostname zabbix --ip 10.0.0.50/24 --gw 10.0.0.1 --appliance zabbix
EOF
  exit 0
}

# Parse arguments
SSH_ROOT="yes"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) VMID="$2"; shift 2 ;;
    --hostname) HOSTNAME="$2"; shift 2 ;;
    --ip) IP="$2"; shift 2 ;;
    --gw) GATEWAY="$2"; shift 2 ;;
    --dns) DNS="$2"; shift 2 ;;
    --dhcp) USE_DHCP=1; shift ;;
    --bridge) BRIDGE="$2"; shift 2 ;;
    --ssh-key) SSH_KEY_FILE="$2"; shift 2 ;;
    --ssh-pubkey) SSH_PUBKEY="$2"; shift 2 ;;
    --disk) DISK_GB="$2"; shift 2 ;;
    --memory) MEMORY_MB="$2"; shift 2 ;;
    --cores) CORES="$2"; shift 2 ;;
    --appliance) APPLIANCE="$2"; shift 2 ;;
    --non-interactive) INTERACTIVE=0; shift ;;
    --ssh-root) SSH_ROOT="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

# Pre-flight
[[ $EUID -eq 0 ]] || die "Must run as root"
command -v pct &>/dev/null || die "pct not found - is this a PVE host?"
command -v pveam &>/dev/null || die "pveam not found"

# Resolve VMID
if [[ -z "$VMID" ]]; then
  VMID=$(pvesh get /cluster/nextid 2>/dev/null) || die "Failed to get next VMID"
fi
if pct status "$VMID" &>/dev/null; then
  die "Container ID $VMID already exists"
fi

# Interactive mode
if [[ $INTERACTIVE -eq 1 ]]; then
  echo ""
  echo "========================================"
  echo "  LXCHub Container Bootstrap"
  echo "========================================"
  echo ""

  if [[ -z "$HOSTNAME" ]]; then
    read -r -p "Hostname [lxchub-${VMID}]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-"lxchub-${VMID}"}
  fi

  if [[ -z "$APPLIANCE" ]]; then
    echo ""
    echo "Available appliances:"
    for d in "${LXCHUB_DIR}/templates/"*/; do
      echo "  - $(basename "$d")"
    done
    echo ""
    read -r -p "Appliance (e.g. wazuh): " APPLIANCE
  fi

  if [[ $USE_DHCP -eq 0 && -z "$IP" ]]; then
    echo ""
    echo "1) DHCP  2) Static IP"
    read -r -p "Network [1]: " net_choice
    if [[ "${net_choice:-1}" == "2" ]]; then
      read -r -p "IP (CIDR): " IP
      read -r -p "Gateway: " GATEWAY
    else
      USE_DHCP=1
    fi
  fi

  if [[ -z "$SSH_KEY_FILE" ]]; then
    echo ""
    read -r -p "SSH public key path (empty to skip): " SSH_KEY_FILE
  fi

  echo ""
  echo "VMID:      $VMID"
  echo "Hostname:  ${HOSTNAME:-lxchub-${VMID}}"
  echo "Appliance: $APPLIANCE"
  echo "Resources: ${CORES}vCPU / ${MEMORY_MB}MB / ${DISK_GB}GB"
  if [[ $USE_DHCP -eq 1 ]]; then
    echo "Network:   DHCP on ${BRIDGE}"
  else
    echo "Network:   ${IP} gw ${GATEWAY} on ${BRIDGE}"
  fi
  echo "SSH key:   ${SSH_KEY_FILE:-none}"
  echo ""
  read -r -p "Proceed? [Y/n]: " confirm
  [[ "${confirm:-y}" =~ ^[Yy] ]] || die "Aborted"
fi

HOSTNAME=${HOSTNAME:-"lxchub-${VMID}"}
APPLIANCE_DIR="${LXCHUB_DIR}/templates/${APPLIANCE}"

# Download template
TEMPLATE_PATH="/var/lib/vz/template/cache/${TEMPLATE_IMAGE}"
if [[ ! -f "$TEMPLATE_PATH" ]]; then
  log "Downloading ${TEMPLATE_IMAGE}..."
  pveam download "${TEMPLATE_STORAGE}" "${TEMPLATE_IMAGE}" || die "Download failed"
fi

# Network args
NET_ARGS=()
if [[ $USE_DHCP -eq 1 ]]; then
  NET_ARGS+=("--net0" "name=eth0,bridge=${BRIDGE},ip=dhcp")
elif [[ -n "$IP" && -n "$GATEWAY" ]]; then
  NET_ARGS+=("--net0" "name=eth0,bridge=${BRIDGE},ip=${IP},gw=${GATEWAY}")
fi

# Create container
log "Creating container ${VMID}..."
pct create "$VMID" "${TEMPLATE_PATH}" \
  --hostname "$HOSTNAME" \
  --rootfs "${TEMPLATE_STORAGE}:${DISK_GB}" \
  --memory "$MEMORY_MB" \
  --cores "$CORES" \
  --unprivileged 1 \
  --nesting 1 \
  --features "keyctl=1,nesting=1" \
  --nameserver "$DNS" \
  --onboot 1 \
  --start 0 \
  --password "lxchub" \
  "${NET_ARGS[@]}"
log "Container ${VMID} created"

# Inline SSH key from --ssh-pubkey
if [[ -n "$SSH_PUBKEY" ]]; then
  SSH_KEY_INLINE="$SSH_PUBKEY"
elif [[ -n "$SSH_KEY_FILE" && -f "$SSH_KEY_FILE" ]]; then
  SSH_KEY_INLINE=$(cat "$SSH_KEY_FILE")
else
  SSH_KEY_INLINE=""
fi

# Generate setup.conf for first-boot automation
SETUP_CONF_CONTENT=""
if [[ -n "$IP" && -n "$GATEWAY" ]]; then
  SETUP_CONF_CONTENT+="STATIC_IP='${IP}'"$'\n'
  SETUP_CONF_CONTENT+="STATIC_GW='${GATEWAY}'"$'\n'
  SETUP_CONF_CONTENT+="STATIC_DNS='${DNS}'"$'\n'
fi
SETUP_CONF_CONTENT+="NEW_HOSTNAME='${HOSTNAME}'"$'\n'
SETUP_CONF_CONTENT+="SSH_ROOT='${SSH_ROOT}'"$'\n'
if [[ -n "$SSH_KEY_INLINE" ]]; then
  SETUP_CONF_CONTENT+="SSH_PUBKEY='${SSH_KEY_INLINE}'"$'\n'
fi

# Copy template files
if [[ -d "$APPLIANCE_DIR" ]]; then
  log "Copying ${APPLIANCE} template..."
  pct exec "$VMID" -- mkdir -p "/opt/lxchub/templates/${APPLIANCE}"
  for f in install.sh validate.sh update.sh healthcheck.sh metadata.yaml; do
    if [[ -f "${APPLIANCE_DIR}/${f}" ]]; then
      pct push "$VMID" "${APPLIANCE_DIR}/${f}" "/opt/lxchub/templates/${APPLIANCE}/${f}"
      pct exec "$VMID" -- chmod +x "/opt/lxchub/templates/${APPLIANCE}/${f}" 2>/dev/null || true
    fi
  done
fi

# Copy pmtui-init.sh and create pmtui command
log "Installing PMTUI first-boot wizard..."
pct push "$VMID" "${LXCHUB_DIR}/templates/pmtui-init.sh" /usr/local/bin/pmtui-init.sh
pct exec "$VMID" -- chmod +x /usr/local/bin/pmtui-init.sh
pct exec "$VMID" -- ln -sf /usr/local/bin/pmtui-init.sh /usr/local/bin/pmtui

# Inject setup.conf for non-interactive first-boot
pct exec "$VMID" -- mkdir -p /etc/lxchub
pct exec "$VMID" -- bash -c "cat >/etc/lxchub/setup.conf <<'SETUP'
${SETUP_CONF_CONTENT}
SETUP"

# Create metadata
pct exec "$VMID" -- bash -c "cat >/etc/lxchub/metadata.json <<'EOF'
{
  \"appliance\": \"${APPLIANCE}\",
  \"deployed\": false,
  \"created\": \"$(date -Iseconds)\",
  \"resources\": {
    \"disk\": ${DISK_GB},
    \"memory\": ${MEMORY_MB},
    \"cores\": ${CORES}
  }
}
EOF"

# Set pmtui-init.sh as default init at LXC kernel level
CT_CONF="/etc/pve/lxc/${VMID}.conf"
if [[ -f "$CT_CONF" ]]; then
  cat >>"$CT_CONF" <<LXC

# LXCHub: PMTUI as default init
lxc.init.cmd = /usr/local/bin/pmtui-init.sh
LXC
  log "lxc.init.cmd set to pmtui-init.sh"
else
  log "WARNING: ${CT_CONF} not found"
fi

# Start
log "Starting container ${VMID}..."
pct start "$VMID"

echo ""
echo "========================================"
echo "  LXCHub Container ${VMID} Deployed!"
echo "========================================"
echo "  Hostname:  ${HOSTNAME}"
echo "  Appliance: ${APPLIANCE}"
echo "  Resources: ${CORES}vCPU / ${MEMORY_MB}MB / ${DISK_GB}GB"
if [[ $USE_DHCP -eq 1 ]]; then
  echo "  Network:   DHCP on ${BRIDGE}"
  echo "  IP:        pct exec ${VMID} -- hostname -I"
else
  echo "  Network:   ${IP}"
fi
echo "  SSH:       ssh root@... (after setup)"
echo "  Console:   pct enter ${VMID}"
echo "  PMTUI:     Runs automatically on first boot"
echo "========================================"
