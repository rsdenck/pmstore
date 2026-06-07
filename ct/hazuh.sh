#!/usr/bin/env bash
# PMStore - HAZUH (Wazuh SOC Appliance) v2
# Usage:
#   Interactive: bash hazuh.sh
#   Headless:    var_cpu="2" var_ram="4096" var_disk="16" IP="10.0.0.1/24" bash hazuh.sh

PMSTACK="\e[96mPMSTACK\e[39m"
RSDENCK="\e[92mrsdenck\e[39m"

msg_info()  { echo -e "  \e[94m[*]\e[39m $1"; }
msg_ok()    { echo -e "  \e[92m[+]\e[39m $1"; }
msg_error() { echo -e "  \e[91m[-]\e[39m $1" >&2; }

header_info() {
  clear
  echo -e "========================================"
  echo -e "  $PMSTACK CONSOLE"
  echo -e "  $RSDENCK"
  echo -e "========================================"
  echo -e "  HAZUH SOC Appliance 4.14.5"
  echo -e "  Rocky Linux 9 - Hardened"
  echo -e "========================================"
}

set -Eeuo pipefail
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR

error_exit() {
  trap - ERR
  msg_error "${1:-Unknown failure} (exit $EXIT @ line $LINE)"
  [ ! -z ${CTID-} ] && cleanup_ctid
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
command -v pveam &>/dev/null || die "pveam not found"

LOG="/tmp/hazuh-deploy.log"
: > "$LOG"

# ── Download PMTUI wizard binary ──
PMTUI_BIN="/tmp/pmtui-wizard"
PMTUI_URL="https://raw.githubusercontent.com/rsdenck/pmstore/main/bin/pmtui-wizard"

download_pmtui_wizard() {
  if [ -x "$PMTUI_BIN" ]; then
    msg_ok "PMTUI wizard already downloaded"
    return 0
  fi
  # Check adjacent paths (when running from cloned repo)
  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  if [ -x "${SCRIPT_DIR}/../bin/pmtui-wizard" ]; then
    cp "${SCRIPT_DIR}/../bin/pmtui-wizard" "$PMTUI_BIN"
    chmod 755 "$PMTUI_BIN"
    msg_ok "PMTUI wizard found locally"
    return 0
  fi
  if [ -x "${SCRIPT_DIR}/bin/pmtui-wizard" ]; then
    cp "${SCRIPT_DIR}/bin/pmtui-wizard" "$PMTUI_BIN"
    chmod 755 "$PMTUI_BIN"
    msg_ok "PMTUI wizard found locally"
    return 0
  fi
  msg_info "Downloading PMTUI wizard..."
  curl -fsSL "$PMTUI_URL" -o "$PMTUI_BIN" || die "Failed to download PMTUI wizard"
  chmod 755 "$PMTUI_BIN"
  msg_ok "PMTUI wizard downloaded ($(stat -c%s "$PMTUI_BIN") bytes)"
}

# ── Interactive deploy wizard ──
run_deploy_wizard() {
  header_info
  echo ""
  local CONFIG_JSON
  CONFIG_JSON=$("$PMTUI_BIN" --deploy 2>/dev/null)
  if [ -z "$CONFIG_JSON" ]; then
    echo "  Wizard cancelled. Exiting."
    exit 0
  fi
  # Parse JSON
  local IP_MODE HOSTNAME DNS_VAL SSH_ENABLED SSH_PORT IP_ADDR NETMASK GW
  IP_MODE=$(echo "$CONFIG_JSON" | grep '"ip_mode"' | cut -d'"' -f4)
  HOSTNAME=$(echo "$CONFIG_JSON" | grep '"hostname"' | cut -d'"' -f4)
  DNS_VAL=$(echo "$CONFIG_JSON" | grep '"dns"' | cut -d'"' -f4)
  SSH_ENABLED=$(echo "$CONFIG_JSON" | grep '"ssh_enabled"' | cut -d: -f2 | tr -d ' ,')
  SSH_PORT=$(echo "$CONFIG_JSON" | grep '"ssh_port"' | cut -d'"' -f4)

  if [ "$IP_MODE" = "static" ]; then
    IP_ADDR=$(echo "$CONFIG_JSON" | grep '"ip"' | head -1 | cut -d'"' -f4)
    NETMASK=$(echo "$CONFIG_JSON" | grep '"netmask"' | cut -d'"' -f4)
    GW=$(echo "$CONFIG_JSON" | grep '"gateway"' | cut -d'"' -f4)
  else
    IP_ADDR="dhcp"
    NETMASK=""
    GW=""
  fi

  var_ip="${IP_ADDR}${NETMASK:+/$NETMASK}"
  var_gw="${GW}"
  var_dns="${DNS_VAL:-8.8.8.8}"
  var_hostname="${HOSTNAME:-HAZUH}"
  var_ssh="${SSH_ENABLED:-true}"
  var_ssh_port="${SSH_PORT:-22}"
}

# ── Defaults ──
CTID=${CTID:-$(pvesh get /cluster/nextid 2>/dev/null)}
var_cpu=${var_cpu:-2}
var_ram=${var_ram:-4096}
var_disk=${var_disk:-16}

# ── Interactive or headless ──
download_pmtui_wizard

if [ -t 0 ] && [ -z "${IP:-}" ] && [ -z "${target_ip:-}" ]; then
  run_deploy_wizard
else
  var_ip="${IP:-192.168.130.10/24}"
  var_gw="${GW:-192.168.130.1}"
  var_dns="${DNS:-8.8.8.8}"
  var_hostname="${HOSTNAME:-HAZUH}"
  var_ssh="${SSH_ENABLED:-true}"
  var_ssh_port="${SSH_PORT:-22}"
fi

header_info
echo ""
msg_info "Creating container CT $CTID ..."
echo -e "       CPU: $var_cpu | RAM: ${var_ram}MB | Disk: ${var_disk}GB"
echo -e "       IP: $var_ip | GW: ${var_gw:-dhcp} | DNS: $var_dns"
echo -e "       SSH: $var_ssh (port ${var_ssh_port:-22})"
echo ""

[[ -f "/etc/pve/lxc/${CTID}.conf" ]] && die "CT $CTID already exists"

TEMPLATE="local:vztmpl/rockylinux-9-default_20240912_amd64.tar.xz"

# Build net0 argument
if [ "$var_ip" = "dhcp" ]; then
  NET_ARGS="name=eth0,bridge=vmbr0,type=veth"
else
  NET_ARGS="name=eth0,bridge=vmbr0,gw=${var_gw},ip=${var_ip},type=veth"
fi

pct create "$CTID" "$TEMPLATE" \
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
  --tags "pmstack;rsdenck" \
  --net0 "$NET_ARGS" &>> "$LOG"

sleep 5
msg_ok "Container created"

# ── SSH config ──
msg_info "Configuring SSH..."
pct exec "$CTID" -- dnf install -y openssh-server &>> "$LOG"
pct exec "$CTID" -- sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
pct exec "$CTID" -- sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
if [ "${var_ssh_port:-22}" != "22" ]; then
  pct exec "$CTID" -- sed -i "s/^#*\\s*Port\\s\\+[0-9]\\+/Port ${var_ssh_port}/" /etc/ssh/sshd_config
fi
if [ "${var_ssh}" = "false" ]; then
  pct exec "$CTID" -- systemctl disable sshd --now &>> "$LOG" || true
else
  pct exec "$CTID" -- systemctl enable sshd --now &>> "$LOG"
fi
msg_ok "SSH configured"

# ── PMTUI — build on host, push to container ──
msg_info "Installing PMTUI in container..."
pct exec "$CTID" -- mkdir -p /etc/lxchub /var/log/lxchub
pct push "$CTID" "$PMTUI_BIN" /usr/local/bin/pmtui &>> "$LOG"
pct exec "$CTID" -- chmod 755 /usr/local/bin/pmtui
pct exec "$CTID" -- bash -c 'echo "/usr/local/bin/pmtui" >> /etc/shells'
pct exec "$CTID" -- usermod -s /usr/local/bin/pmtui root
msg_ok "PMTUI installed as default shell"

# ── Metadata ──
pct exec "$CTID" -- bash -c "cat > /etc/lxchub/metadata.json << 'EOF'
{
  \"appliance\": \"hazuh\",
  \"deployed\": false,
  \"resources\": {
    \"disk\": ${var_disk},
    \"memory\": ${var_ram},
    \"cores\": ${var_cpu}
  }
}
EOF"

# ── SOC Hardening ──
msg_info "Applying SOC hardening..."
pct exec "$CTID" -- bash -c "cat > /etc/sysctl.d/99-soc-hardening.conf << 'SYSCTL'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.conf.all.log_martians = 1
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
SYSCTL"
pct exec "$CTID" -- sysctl -p /etc/sysctl.d/99-soc-hardening.conf &>> "$LOG"
pct exec "$CTID" -- bash -c 'echo "umask 027" >> /etc/profile.d/umask.sh'
pct exec "$CTID" -- bash -c 'chmod 644 /etc/profile.d/umask.sh'
msg_ok "SOC hardening applied"

# ── Disk resize ──
pct resize "$CTID" rootfs "${var_disk}G" &>> "$LOG" || true

echo ""
echo -e "========================================"
echo -e "  $PMSTACK CONSOLE"
echo -e "  $RSDENCK"
echo -e "========================================"
msg_ok "HAZUH CT $CTID deployed!"
echo "       Hostname: ${var_hostname}"
echo "       IP: ${var_ip%/*}"
echo "       SSH: ssh root@${var_ip%/*} (pass: lxchub) port ${var_ssh_port:-22}"
echo "       PMTUI on console/SSH"
echo ""
echo "  Run the Wazuh install script to deploy the stack."
echo ""
