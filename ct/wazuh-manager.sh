#!/usr/bin/env bash
set -Eeuo pipefail

PMSTACK="\e[96mPMSTACK\e[39m"
RSDENCK="\e[92mrsdenck\e[39m"

header_info() {
  clear
  echo -e "========================================"
  echo -e "  $PMSTACK CONSOLE"
  echo -e "  $RSDENCK"
  echo -e "========================================"
  echo -e "  Wazuh Manager 4.14.5 - Rocky Linux 9"
  echo -e "========================================"
}

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

CTID=${CTID:-$(pvesh get /cluster/nextid 2>/dev/null)}
var_cpu=${var_cpu:-1}
var_ram=${var_ram:-2048}
var_disk=${var_disk:-6}
IP="192.168.130.15/24"
GW="192.168.130.1"
DNS="8.8.8.8"

header_info
echo -e "Deploying Wazuh Manager CT $CTID..."
echo -e "CPU: $var_cpu | RAM: ${var_ram}MB | Disk: ${var_disk}GB"
echo -e "IP: $IP | GW: $GW"
echo ""

[[ -f "/etc/pve/lxc/${CTID}.conf" ]] && die "CT $CTID already exists"

TEMPLATE="local:vztmpl/rockylinux-9-default_20240912_amd64.tar.xz"
pct create "$CTID" "$TEMPLATE" \
  --hostname "wazuh-manager" \
  --rootfs "local:${var_disk}" \
  --memory "$var_ram" \
  --cores "$var_cpu" \
  --unprivileged 1 \
  --features "keyctl=1,nesting=1" \
  --nameserver "$DNS" \
  --onboot 1 \
  --start 0 \
  --password "lxchub" \
  --tags "pmstack;rsdenck" \
  --net0 "name=eth0,bridge=vmbr0,gw=${GW},ip=${IP}"

pct start "$CTID"
sleep 3

pct exec "$CTID" -- mkdir -p /opt/lxchub/templates/wazuh /etc/lxchub /var/log/lxchub /tmp
pct push "$CTID" /opt/lxchub/ct/pmtui/init.sh /usr/local/bin/pmtui
pct exec "$CTID" -- chmod +x /usr/local/bin/pmtui
pct exec "$CTID" -- bash -c 'echo "/usr/local/bin/pmtui" >> /etc/shells'
pct exec "$CTID" -- usermod -s /usr/local/bin/pmtui root
pct exec "$CTID" -- dnf install -y openssh-server 2>&1 | tail -3
pct exec "$CTID" -- systemctl enable sshd --now 2>&1

cat > /tmp/pmstore-metadata-${CTID}.json <<EOF
{
  "appliance": "wazuh-manager",
  "deployed": true,
  "created": "$(date -Iseconds)",
  "resources": {
    "disk": ${var_disk},
    "memory": ${var_ram},
    "cores": ${var_cpu}
  }
}
EOF
pct push "$CTID" /tmp/pmstore-metadata-${CTID}.json /etc/lxchub/metadata.json
pct exec "$CTID" -- touch /etc/lxchub/.first-boot-done

pct exec "$CTID" -- systemctl restart sshd 2>/dev/null || true

echo ""
echo -e "========================================"
echo -e "  $PMSTACK CONSOLE"
echo -e "  $RSDENCK"
echo -e "========================================"
echo -e "  Wazuh Manager CT $CTID deployed!"
echo -e "  IP: ${IP%/*}"
echo -e "  PMTUI on console/SSH"
echo -e "========================================"
