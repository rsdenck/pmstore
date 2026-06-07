#!/usr/bin/env bash
set -Eeuo pipefail

# ======================================================================
# PMTUI Init - Container entrypoint (PID 1) / Management Interface
# ======================================================================
# As PID 1 (via lxc.init.cmd):
#   First boot: runs setup wizard or reads setup.conf, then exec systemd
#   Subsequent: immediately exec systemd (transparent, fast boot)
#
# As CLI (invoked via pmtui command):
#   Shows interactive management menu
# ======================================================================

PMSTORE_DIR="/opt/lxchub"
APP_DIR="${PMSTORE_DIR}/ct"
SETUP_LOG="/var/log/lxchub/setup.log"
SETUP_CONF="/etc/lxchub/setup.conf"
METADATA_FILE="/etc/lxchub/metadata.json"
FIRST_BOOT_FLAG="/etc/lxchub/.first-boot-done"
FIRST_BOOT_SCRIPT="/etc/lxchub/.first-boot.sh"

mkdir -p /var/log/lxchub /etc/lxchub

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$SETUP_LOG"
}

detect_appliance() {
  if [[ -f "$METADATA_FILE" ]]; then
    grep -o '"appliance": *"[^"]*"' "$METADATA_FILE" | cut -d'"' -f4
  fi
}

# ======================================================================
# Non-interactive setup - reads setup.conf
# ======================================================================
apply_noninteractive_config() {
  log "Applying non-interactive configuration from ${SETUP_CONF}"

  if [[ -f "$SETUP_CONF" ]]; then
    # shellcheck source=/dev/null
    source "$SETUP_CONF"
  fi

  if [[ -n "${STATIC_IP:-}" && -n "${STATIC_GW:-}" ]]; then
    local STATIC_DNS="${STATIC_DNS:-8.8.8.8}"
    cat >/etc/network/interfaces <<NETCFG
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address ${STATIC_IP}
  gateway ${STATIC_GW}
  dns-nameservers ${STATIC_DNS}
NETCFG
    echo "nameserver ${STATIC_DNS}" >/etc/resolv.conf
    log "Static IP: ${STATIC_IP}"
  fi

  if [[ -n "${NEW_HOSTNAME:-}" ]]; then
    hostname "$NEW_HOSTNAME"
    echo "$NEW_HOSTNAME" >/etc/hostname
    sed -i "/^127.0.1.1/d" /etc/hosts
    echo "127.0.1.1 ${NEW_HOSTNAME}" >>/etc/hosts
    log "Hostname: ${NEW_HOSTNAME}"
  fi

  if [[ "${SSH_ROOT:-yes}" =~ ^[Yy] ]]; then
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    log "Root SSH login enabled"
  fi

  if [[ -n "${SSH_PUBKEY:-}" ]]; then
    mkdir -p /root/.ssh
    echo "$SSH_PUBKEY" >>/root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    log "SSH key injected"
  fi

}

# ======================================================================
# Interactive first-boot wizard
# ======================================================================
first_boot_wizard() {
  echo ""
  echo "========================================"
  echo "  PMSTACK CONSOLE"
  echo "  rsdenck"
  echo "========================================"
  echo "  Appliance Setup"
  echo ""

  local APPLIANCE
  APPLIANCE=$(detect_appliance)

  echo "--- Network Configuration ---"
  ip -br addr show 2>/dev/null || true
  echo ""
  echo "1) DHCP"
  echo "2) Static IP"
  read -r -p "Network mode [1]: " net_mode

  if [[ "${net_mode:-1}" == "2" ]]; then
    read -r -p "IP (CIDR, e.g. 192.168.1.100/24): " STATIC_IP
    read -r -p "Gateway: " STATIC_GW
    read -r -p "DNS [8.8.8.8]: " STATIC_DNS
    STATIC_DNS=${STATIC_DNS:-8.8.8.8}

    cat >/etc/network/interfaces <<NETCFG
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address ${STATIC_IP}
  gateway ${STATIC_GW}
  dns-nameservers ${STATIC_DNS}
NETCFG
    echo "nameserver ${STATIC_DNS}" >/etc/resolv.conf
    log "Static IP configured: ${STATIC_IP}"
  fi

  echo ""
  local CURRENT_HOST
  CURRENT_HOST=$(hostname)
  read -r -p "Hostname [${CURRENT_HOST}]: " NEW_HOSTNAME
  NEW_HOSTNAME=${NEW_HOSTNAME:-$CURRENT_HOST}
  hostname "$NEW_HOSTNAME"
  echo "$NEW_HOSTNAME" >/etc/hostname
  sed -i "/^127.0.1.1/d" /etc/hosts
  echo "127.0.1.1 ${NEW_HOSTNAME}" >>/etc/hosts
  log "Hostname: ${NEW_HOSTNAME}"

  echo ""
  echo "--- SSH ---"
  read -r -p "Enable root SSH login? [Y/n]: " ssh_root
  if [[ "${ssh_root:-y}" =~ ^[Yy] ]]; then
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    log "Root SSH login enabled"
  fi

  read -r -p "Paste SSH public key (or leave empty): " SSH_PUBKEY
  if [[ -n "$SSH_PUBKEY" ]]; then
    mkdir -p /root/.ssh
    echo "$SSH_PUBKEY" >>/root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    log "SSH key added"
  fi

  if [[ -z "$APPLIANCE" || ! -d "${APP_DIR}/${APPLIANCE}" ]]; then
    echo ""
    echo "--- Appliance ---"
    for d in "${APP_DIR}/"*/; do
      echo "  $(basename "$d")"
    done
    echo ""
    read -r -p "Appliance to install: " APPLIANCE
    # Update metadata with selected appliance
    cat >"$METADATA_FILE" <<EOF
{
  "appliance": "${APPLIANCE}",
  "deployed": false,
  "created": "$(date -Iseconds)",
  "resources": {}
}
EOF
  fi

  echo ""
  echo "========================================"
  echo "  Configuration Complete!"
  echo "  ${APPLIANCE} will install after reboot."
  echo "  Management: pmtui"
  echo "========================================"
  echo ""
}

# ======================================================================
# Run appliance installation (called from setup)
# ======================================================================
run_install() {
  local APPLIANCE
  APPLIANCE=$(detect_appliance)
  local INSTALL_SCRIPT="${APP_DIR}/${APPLIANCE}/install.sh"

  if [[ -f "$INSTALL_SCRIPT" ]]; then
    echo "Installing ${APPLIANCE}..."
    bash "$INSTALL_SCRIPT" 2>&1 | tee -a "$SETUP_LOG"
    log "Installation of ${APPLIANCE} completed"
    echo "Done."
  else
    echo "No install script for ${APPLIANCE}"
  fi
}

# ======================================================================
# Management menu (when invoked as pmtui CLI)
# ======================================================================
pmtui_menu() {
  while true; do
    clear 2>/dev/null || true
    echo "========================================"
    echo "  PMSTACK CONSOLE"
    echo "  rsdenck"
    echo "========================================"
    echo "  Appliance: $(detect_appliance)"
    echo "  Hostname:  $(hostname)"
    echo "  IP:        $(hostname -I 2>/dev/null | awk '{print $1}')"
    echo "========================================"
    echo ""
    echo "1) Application Information"
    echo "2) Service Status"
    echo "3) Restart Services"
    echo "4) Validate Installation"
    echo "5) Health Check"
    echo "6) Update Appliance"
    echo "7) Show Logs"
    echo "8) Run Install"
    echo "9) Access Bash"
    echo "0) Exit"
    echo ""
    read -r -p "Choice [0-9]: " choice

    case "$choice" in
      1)
        echo ""
        echo "--- Application Info ---"
        cat "$METADATA_FILE" 2>/dev/null || echo "No metadata"
        echo ""
        echo "Installed scripts in ${APP_DIR}/$(detect_appliance)/"
        ls -la "${APP_DIR}/$(detect_appliance)/" 2>/dev/null || echo "(empty)"
        ;;
      2)
        echo ""
        systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{print "  " $1}' || echo "  (systemd not available)"
        ;;
      3)
        echo ""
        read -r -p "Service name (or 'all'): " svc
        if [[ "$svc" == "all" ]]; then
          systemctl restart --all 2>/dev/null || true
        else
          systemctl restart "$svc" 2>/dev/null || true
        fi
        echo "Done."
        ;;
      4)
        local VALIDATE_SCRIPT="${APP_DIR}/$(detect_appliance)/validate.sh"
        if [[ -f "$VALIDATE_SCRIPT" ]]; then bash "$VALIDATE_SCRIPT"; else echo "No validate.sh"; fi
        ;;
      5)
        local HEALTH_SCRIPT="${APP_DIR}/$(detect_appliance)/healthcheck.sh"
        if [[ -f "$HEALTH_SCRIPT" ]]; then bash "$HEALTH_SCRIPT"; else echo "No healthcheck.sh"; fi
        ;;
      6)
        local UPDATE_SCRIPT="${APP_DIR}/$(detect_appliance)/update.sh"
        if [[ -f "$UPDATE_SCRIPT" ]]; then bash "$UPDATE_SCRIPT"; else echo "No update.sh"; fi
        ;;
      7)
        echo ""
        echo "=== Setup Log ==="
        cat "$SETUP_LOG" 2>/dev/null || echo "(empty)"
        echo ""
        echo "=== Install Log ==="
        cat /var/log/lxchub/install.log 2>/dev/null || echo "(empty)"
        echo ""
        echo "=== Health Log ==="
        cat /var/log/lxchub/healthcheck.log 2>/dev/null || echo "(empty)"
        ;;
      8)
        run_install
        ;;
       9)
        echo ""
        echo "--- Bash Shell (type 'exit' to return to PMTUI) ---"
        /bin/bash
        ;;
       0)
        exit 0
        ;;
    esac
    echo ""
    echo "Press Enter to continue..."
    read -r
  done
}

# ======================================================================
# Create systemd oneshot service for appliance installation
# ======================================================================
create_install_service() {
  local APPLIANCE
  APPLIANCE=$(detect_appliance)
  local INSTALL_SCRIPT="${APP_DIR}/${APPLIANCE}/install.sh"

  cat >/etc/systemd/system/lxchub-install.service <<UNIT
[Unit]
Description=LXCHub Appliance Installation
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${INSTALL_SCRIPT}
ExecStartPost=/bin/bash -c 'systemctl disable lxchub-install.service'
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
UNIT

  systemctl enable lxchub-install.service 2>/dev/null || true
  log "Install service lxchub-install.service created and enabled"
}

# ======================================================================
# Main
# ======================================================================
main() {
  # Check if running as PID 1 (init process)
  if [[ $$ -eq 1 ]]; then
    log "PMTUI-Init started as PID 1"

    if [[ ! -f "$FIRST_BOOT_FLAG" ]]; then
      log "First boot detected"

      # Phase 1: configure base system (network, hostname, SSH)
      # These work without systemd
      if [[ -f "$SETUP_CONF" ]]; then
        apply_noninteractive_config
      else
        first_boot_wizard
      fi

      # Phase 2: create systemd service for appliance install
      # Install runs after systemd boots (needs apt, systemctl, etc.)
      create_install_service

      date >"$FIRST_BOOT_FLAG"
      log "First boot config done. Install will run after systemd starts."
    fi

    log "Execing systemd as PID 1..."
    exec /lib/systemd/systemd
  fi

  # Running as CLI command
  pmtui_menu
}

main "$@"
