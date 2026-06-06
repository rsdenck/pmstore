#!/usr/bin/env bash
set -Eeuo pipefail

LXCHUB_LOG_DIR="/var/log/lxchub"
VALIDATE_LOG="${LXCHUB_LOG_DIR}/validate.log"

mkdir -p "${LXCHUB_LOG_DIR}"
exec > >(tee -a "${VALIDATE_LOG}") 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

ERRORS=0

validate_packages() {
  log "Validating packages..."
  local packages=("wazuh-manager" "wazuh-indexer" "wazuh-dashboard" "filebeat")
  for pkg in "${packages[@]}"; do
    if dpkg -l "$pkg" &>/dev/null; then
      log "  OK: $pkg is installed"
    else
      log "  FAIL: $pkg is NOT installed"
      ((ERRORS++))
    fi
  done
}

validate_services() {
  log "Validating services..."
  local services=("wazuh-manager" "wazuh-indexer" "wazuh-dashboard" "filebeat")
  for svc in "${services[@]}"; do
    if systemctl is-active --quiet "$svc"; then
      log "  OK: $svc is active"
    else
      log "  FAIL: $svc is NOT active"
      ((ERRORS++))
    fi
  done
}

validate_ports() {
  log "Validating listening ports..."
  local ports=(443 55000 9200 1514 1515 1516)
  for port in "${ports[@]}"; do
    if ss -tlnp "sport = :${port}" 2>/dev/null | grep -q LISTEN; then
      log "  OK: port ${port} is listening"
    else
      log "  FAIL: port ${port} is NOT listening"
      ((ERRORS++))
    fi
  done
}

validate_api() {
  log "Validating Wazuh API..."
  local TOKEN
  TOKEN=$(curl -s -u admin:admin -k "https://localhost:55000/security/user/authenticate" 2>/dev/null | jq -r '.data.token // empty' 2>/dev/null || true)
  if [[ -n "$TOKEN" ]]; then
    log "  OK: Wazuh API authentication works"
  else
    log "  FAIL: Wazuh API is not responding"
    ((ERRORS++))
  fi
}

validate_indexer_health() {
  log "Validating Wazuh Indexer health..."
  local HEALTH
  HEALTH=$(curl -s -k "https://localhost:9200/_cluster/health" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)
  if [[ "$HEALTH" =~ ^(green|yellow)$ ]]; then
    log "  OK: Indexer cluster health is ${HEALTH}"
  else
    log "  FAIL: Indexer cluster health is ${HEALTH:-unreachable}"
    ((ERRORS++))
  fi
}

validate_dashboard() {
  log "Validating Wazuh Dashboard..."
  local HTTP_CODE
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k "https://localhost/" 2>/dev/null || true)
  if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" || "$HTTP_CODE" == "301" ]]; then
    log "  OK: Dashboard returned HTTP ${HTTP_CODE}"
  else
    log "  FAIL: Dashboard returned HTTP ${HTTP_CODE:-unreachable}"
    ((ERRORS++))
  fi
}

validate_pmtui() {
  log "Validating PMTUI integration..."
  if [[ -f "/etc/pmtui/appliances/wazuh.yaml" ]]; then
    log "  OK: PMTUI registration exists"
  else
    log "  FAIL: PMTUI registration NOT found"
    ((ERRORS++))
  fi
}

main() {
  log "=== Wazuh Validation Started ==="

  validate_packages
  validate_services
  validate_ports
  validate_api
  validate_indexer_health
  validate_dashboard
  validate_pmtui

  log "=== Validation Complete ==="
  if [[ $ERRORS -gt 0 ]]; then
    log "RESULT: FAILED - ${ERRORS} error(s) found"
    exit 1
  else
    log "RESULT: PASSED - All checks successful"
    exit 0
  fi
}

main "$@"
