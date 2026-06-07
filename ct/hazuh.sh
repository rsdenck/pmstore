#!/usr/bin/env bash
# PMStore - HAZUH (Wazuh SOC Appliance)
# Usage:
#   Interactive: bash hazuh.sh
#   Headless:    var_cpu="2" var_ram="4096" var_disk="16" IP="10.0.0.1/24" bash hazuh.sh

PMSTACK="\e[96mPMSTACK\e[39m"
RSDENCK="\e[92mrsdenck\e[39m"

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
  local REASON="\e[97m${1:-Unknown failure}\e[39m"
  local FLAG="\e[91m[ERROR]\e[39m \e[93m$EXIT@$LINE"
  echo -e "$FLAG $REASON" >&2
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

# ── Build PMTUI on PVE host if needed ──
build_pmtui() {
  local BIN="${1:-/tmp/pmtui}"
  if [ -x "$BIN" ]; then return 0; fi
  if ! command -v go &>/dev/null; then
    echo "  Installing Go..."
    apt-get install -y golang-go 2>/dev/null || dnf install -y golang 2>/dev/null || die "Cannot install Go"
  fi
  local TMPDIR="/tmp/pmo-build-$$"
  git clone --depth 1 https://github.com/rsdenck/pmo.git "$TMPDIR" 2>&1 | tail -1
  CGO_ENABLED=0 go build -o "$BIN" -ldflags="-s -w" "${TMPDIR}/pmtui/" 2>&1
  rm -rf "$TMPDIR"
  [ -x "$BIN" ] || die "PMTUI build failed"
}

# ── Interactive deploy wizard via PMTUI ──
run_deploy_wizard() {
  header_info
  echo -e "  Starting PMTUI Deploy Wizard..."
  echo ""
  local PMTUI_BIN="/tmp/pmtui-deploy-$$"
  build_pmtui "$PMTUI_BIN"
  # Run wizard and capture JSON output
  local CONFIG_JSON
  CONFIG_JSON=$("$PMTUI_BIN" --deploy 2>/dev/null)
  rm -f "$PMTUI_BIN"
  if [ -z "$CONFIG_JSON" ]; then
    echo "  Wizard cancelled. Exiting."
    exit 0
  fi
  echo "$CONFIG_JSON"

  # Parse JSON output
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

  # Set vars for container creation
  var_ip="${IP_ADDR}${NETMASK:+/$NETMASK}"
  var_gw="${GW}"
  var_dns="${DNS_VAL:-8.8.8.8}"
  var_hostname="${HOSTNAME:-HAZUH}"
  var_ssh="${SSH_ENABLED:-true}"
  var_ssh_port="${SSH_PORT:-22}"
}

# ── Defaults (used for headless mode) ──
CTID=${CTID:-$(pvesh get /cluster/nextid 2>/dev/null)}
var_cpu=${var_cpu:-2}
var_ram=${var_ram:-4096}
var_disk=${var_disk:-16}

# Detect interactive mode: prompt via PMTUI wizard when no IP is pre-set
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
echo -e "Deploying HAZUH CT $CTID..."
echo -e "CPU: $var_cpu | RAM: ${var_ram}MB | Disk: ${var_disk}GB"
echo -e "IP: $var_ip | GW: ${var_gw:-dhcp} | DNS: $var_dns"
echo -e "SSH: $var_ssh (port $var_ssh_port)"
echo ""

[[ -f "/etc/pve/lxc/${CTID}.conf" ]] && die "CT $CTID already exists"

TEMPLATE="local:vztmpl/rockylinux-9-default_20240912_amd64.tar.xz"

# Build net0 argument
if [ "$var_ip" = "dhcp" ]; then
  NET_ARGS="name=eth0,bridge=vmbr0,type=veth"
else
  NET_ARGS="name=eth0,bridge=vmbr0,gw=${var_gw},ip=${var_ip},type=veth"
fi

# Create container
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
  --net0 "$NET_ARGS"

sleep 5

# SSH config
pct exec "$CTID" -- dnf install -y openssh-server 2>&1 | tail -1
pct exec "$CTID" -- sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
pct exec "$CTID" -- sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
# Apply SSH port from wizard
if [ "${var_ssh_port:-22}" != "22" ]; then
  pct exec "$CTID" -- sed -i "s/^#*\\s*Port\\s\\+[0-9]\\+/Port ${var_ssh_port}/" /etc/ssh/sshd_config
fi
if [ "${var_ssh}" = "false" ]; then
  pct exec "$CTID" -- systemctl disable sshd --now 2>/dev/null || true
else
  pct exec "$CTID" -- systemctl enable sshd --now
fi

# PMTUI - Go binary from rsdenck/pmo (build inside container)
pct exec "$CTID" -- mkdir -p /opt/lxchub/templates/hazuh /etc/lxchub /var/log/lxchub
pct exec "$CTID" -- dnf install -y golang git 2>&1 | tail -1
pct exec "$CTID" -- git clone --depth 1 https://github.com/rsdenck/pmo.git /tmp/pmo 2>&1 | tail -1
pct exec "$CTID" -- CGO_ENABLED=0 go build -o /usr/local/bin/pmtui -ldflags="-s -w" /tmp/pmo/pmtui/
pct exec "$CTID" -- rm -rf /tmp/pmo
pct exec "$CTID" -- chmod +x /usr/local/bin/pmtui
pct exec "$CTID" -- dnf remove -y golang git 2>&1 | tail -1
pct exec "$CTID" -- bash -c 'echo "/usr/local/bin/pmtui" >> /etc/shells'
pct exec "$CTID" -- usermod -s /usr/local/bin/pmtui root

# Metadata
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
pct exec "$CTID" -- touch /etc/lxchub/.first-boot-done

# SOC Hardening
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
pct exec "$CTID" -- sysctl -p /etc/sysctl.d/99-soc-hardening.conf 2>&1 | tail -1

# Resize disk if needed
pct resize "$CTID" rootfs "${var_disk}G" 2>/dev/null || true

echo ""
echo -e "========================================"
echo -e "  $PMSTACK CONSOLE"
echo -e "  $RSDENCK"
echo -e "========================================"
echo -e "  HAZUH CT $CTID deployed!"
echo -e "  Hostname: ${var_hostname}"
echo -e "  IP: ${var_ip%/*}"
echo -e "  SSH: ssh root@${var_ip%/*} (pass: lxchub) port ${var_ssh_port}"
echo -e "  PMTUI on console/SSH"
echo -e "  Run install script to deploy Wazuh"
echo -e "========================================"
