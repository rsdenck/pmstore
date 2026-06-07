#!/usr/bin/env bash
set -Eeuo pipefail

LXCHUB_LOG_DIR="/var/log/lxchub"
UPDATE_LOG="${LXCHUB_LOG_DIR}/update.log"

mkdir -p "${LXCHUB_LOG_DIR}"
exec > >(tee -a "${UPDATE_LOG}") 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

BACKUP_DIR="/var/backups/lxchub/wazuh/$(date +%Y%m%d_%H%M%S)"

backup_configs() {
  log "Backing up configuration files..."
  mkdir -p "${BACKUP_DIR}"

  local files=(
    "/etc/wazuh-manager/ossec.conf"
    "/etc/wazuh-indexer/opensearch.yml"
    "/etc/wazuh-dashboard/opensearch_dashboards.yml"
    "/etc/filebeat/filebeat.yml"
  )

  for f in "${files[@]}"; do
    if [[ -f "$f" ]]; then
      cp "$f" "${BACKUP_DIR}/"
      log "  Backed up: $f"
    fi
  done

  log "Backup saved to ${BACKUP_DIR}"
}

update_system() {
  log "Updating system packages..."
  apt-get update
  apt-get upgrade -y
  log "System packages updated"
}

update_wazuh() {
  log "Updating Wazuh components..."

  local components=("wazuh-indexer" "wazuh-manager" "wazuh-dashboard" "filebeat")
  for comp in "${components[@]}"; do
    if dpkg -l "$comp" &>/dev/null; then
      log "  Updating ${comp}..."
      apt-get install --only-upgrade -y "$comp"
    fi
  done

  log "Wazuh components updated"
}

restart_services() {
  log "Restarting services..."

  local services=("wazuh-indexer" "wazuh-manager" "wazuh-dashboard" "filebeat")
  for svc in "${services[@]}"; do
    if systemctl is-active --quiet "$svc"; then
      systemctl restart "$svc"
      log "  Restarted: ${svc}"
    fi
  done
}

main() {
  log "=== Wazuh Update Started ==="

  backup_configs
  update_system
  update_wazuh
  restart_services

  # Run validation after update
  log "Running post-update validation..."
  /opt/lxchub/templates/wazuh/validate.sh

  log "=== Wazuh Update Completed ==="
}

main "$@"
