#!/usr/bin/env bash
# PMStore - HAZUH (Wazuh SOC Appliance)
# Usage: var_cpu="2" var_ram="4096" var_disk="16" bash -c "$(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/hazuh.sh)"

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

CTID=${CTID:-$(pvesh get /cluster/nextid 2>/dev/null)}
var_cpu=${var_cpu:-2}
var_ram=${var_ram:-4096}
var_disk=${var_disk:-16}
IP=${IP:-"192.168.130.10/24"}
GW=${GW:-"192.168.130.1"}
DNS=${DNS:-"8.8.8.8"}

header_info
echo -e "Deploying HAZUH CT $CTID..."
echo -e "CPU: $var_cpu | RAM: ${var_ram}MB | Disk: ${var_disk}GB"
echo -e "IP: $IP | GW: $GW"
echo ""

[[ -f "/etc/pve/lxc/${CTID}.conf" ]] && die "CT $CTID already exists"

TEMPLATE="local:vztmpl/rockylinux-9-default_20240912_amd64.tar.xz"

# Create container
pct create "$CTID" "$TEMPLATE" \
  --hostname "HAZUH" \
  --rootfs "lxc-storage:${var_disk}" \
  --memory "$var_ram" \
  --cores "$var_cpu" \
  --unprivileged 1 \
  --features "keyctl=1,nesting=1" \
  --nameserver "$DNS" \
  --onboot 1 \
  --start 1 \
  --password "lxchub" \
  --tags "pmstack;rsdenck" \
  --net0 "name=eth0,bridge=vmbr0,gw=${GW},ip=${IP}"

sleep 5

# SSH config
pct exec "$CTID" -- dnf install -y openssh-server 2>&1 | tail -1
pct exec "$CTID" -- sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
pct exec "$CTID" -- sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
pct exec "$CTID" -- systemctl enable sshd --now

# PMTUI - Go binary from rsdenck/pmo
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
echo -e "  IP: ${IP%/*}"
echo -e "  SSH: ssh root@${IP%/*} (pass: lxchub)"
echo -e "  PMTUI on console/SSH"
echo -e "  Run install script to deploy Wazuh"
echo -e "========================================"
