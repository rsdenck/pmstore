#!/usr/bin/env bash
# PMStore — HAZUH (Wazuh SOC Appliance) v3
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/hazuh.sh
# Usage:
#   Interactive:                    bash hazuh.sh
#   Headless:    IP="10.0.0.1/24"   bash hazuh.sh
#   Remote:      var_cpu="2" var_ram="4096" var_disk="16" bash -c "$(curl -fsSL https://pmoflow.pro/hazuh.sh)"

# ── Load PMStack framework ──
if [ -f "$(dirname "$0")/../core/pmstack.func" ]; then
  source "$(dirname "$0")/../core/pmstack.func"
else
  source <(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/core/pmstack.func)
fi

# ── Appliance definition ──
APP="HAZUH"
APPLIANCE="hazuh"
VERSION="4.14.5"
TAGS="pmstack;rsdenck"
TEMPLATE="local:vztmpl/rockylinux-9-default_20240912_amd64.tar.xz"

# ── Defaults (overridable via environment) ──
CTID=${CTID:-$(next_ctid)}
var_cpu=${var_cpu:-2}
var_ram=${var_ram:-4096}
var_disk=${var_disk:-16}
LOG="/tmp/hazuh-deploy.log"
: > "$LOG"

# ── Error handling ──
check_root
check_pct
catch_errors

# ── Interactive or headless ──
download_pmtui_wizard

if [ -t 0 ] && [ -z "${IP:-}" ]; then
  header_info
  appliance_header "$APP" "$VERSION"
  echo ""
  CONFIG_JSON=$(run_pmtui_deploy)
  IP_MODE=$(echo "$CONFIG_JSON" | grep '"ip_mode"' | cut -d'"' -f4)
  HOSTNAME=$(echo "$CONFIG_JSON" | grep '"hostname"' | cut -d'"' -f4)
  DNS_VAL=$(echo "$CONFIG_JSON" | grep '"dns"' | cut -d'"' -f4)
  SSH_ENABLED=$(echo "$CONFIG_JSON" | grep '"ssh_enabled"' | cut -d: -f2 | tr -d ' ,')
  SSH_PORT=$(echo "$CONFIG_JSON" | grep '"ssh_port"' | cut -d'"' -f4)
  if [ "$IP_MODE" = "static" ]; then
    IP_ADDR=$(echo "$CONFIG_JSON" | grep '"ip"' | head -1 | cut -d'"' -f4)
    NETMASK=$(echo "$CONFIG_JSON" | grep '"netmask"' | cut -d'"' -f4)
    GW=$(echo "$CONFIG_JSON" | grep '"gateway"' | cut -d'"' -f4)
    var_ip="${IP_ADDR}${NETMASK:+/$NETMASK}"
    var_gw="${GW}"
  else
    var_ip="dhcp"
    var_gw=""
  fi
  var_dns="${DNS_VAL:-8.8.8.8}"
  var_hostname="${HOSTNAME:-HAZUH}"
  var_ssh="${SSH_ENABLED:-true}"
  var_ssh_port="${SSH_PORT:-22}"
else
  var_ip="${IP:-192.168.130.10/24}"
  var_gw="${GW:-192.168.130.1}"
  var_dns="${DNS:-8.8.8.8}"
  var_hostname="${HOSTNAME:-HAZUH}"
  var_ssh="${SSH_ENABLED:-true}"
  var_ssh_port="${SSH_PORT:-22}"
fi

header_info
appliance_header "$APP" "$VERSION"
echo ""
msg_info "Creating container CT ${CTID} ..."
echo "       CPU: ${var_cpu} | RAM: ${var_ram}MB | Disk: ${var_disk}GB"
echo "       IP: ${var_ip} | GW: ${var_gw:-dhcp} | DNS: ${var_dns}"
echo "       SSH: ${var_ssh} (port ${var_ssh_port:-22})"
echo ""

ct_exists "$CTID" && die "CT $CTID already exists"

NET_ARGS=$(build_net_args "$var_ip" "${var_gw:-}")

create_lxc "$CTID" "$TEMPLATE" \
  --hostname "${var_hostname}" \
  --rootfs "lxc-storage:${var_disk}" \
  --memory "$var_ram" \
  --cores "$var_cpu" \
  --unprivileged 1 \
  --features "keyctl=1,nesting=1" \
  --nameserver "$var_dns" \
  --onboot 1 \
  --start 1 \
  --password "lxchub" \
  --tags "$TAGS" \
  --net0 "$NET_ARGS"

sleep 5
msg_ok "Container created"

msg_info "Setting root password..."
exec_lxc "$CTID" bash -c 'echo "root:lxchub" | chpasswd'
msg_ok "Root password set"

msg_info "Configuring SSH..."
config_ssh "$CTID" "$var_ssh" "${var_ssh_port:-22}"
msg_ok "SSH configured"

msg_info "Installing PMTUI..."
install_pmtui_container "$CTID"
msg_ok "PMTUI installed"

msg_info "Writing metadata..."
write_metadata "$CTID" "$APPLIANCE" "$var_disk" "$var_ram" "$var_cpu"
msg_ok "Metadata written"

msg_info "Applying SOC hardening..."
apply_soc_hardening "$CTID"
msg_ok "SOC hardening applied"

resize_lxc "$CTID" "$var_disk"

echo ""
echo -e "========================================"
echo -e "  ${C_BOLD}${C_CYAN}PMSTACK CONSOLE${C_RESET}"
echo -e "  ${C_GREEN}rsdenck${C_RESET}"
echo -e "========================================"
msg_ok "${APP} CT ${CTID} deployed!"
echo "       Hostname: ${var_hostname}"
echo "       IP: ${var_ip%/*}"
echo "       SSH: ssh root@${var_ip%/*} (pass: lxchub) port ${var_ssh_port:-22}"
echo "       PMTUI: on console/SSH"
echo ""
echo "  Run the Wazuh install script to deploy the stack."
echo ""
