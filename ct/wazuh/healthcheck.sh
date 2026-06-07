#!/usr/bin/env bash
set -Eeuo pipefail

LXCHUB_LOG_DIR="/var/log/lxchub"
HEALTH_LOG="${LXCHUB_LOG_DIR}/healthcheck.log"

mkdir -p "${LXCHUB_LOG_DIR}"
exec > >(tee -a "${HEALTH_LOG}") 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

FAILURES=0

check_service() {
  local svc="$1"
  if systemctl is-active --quiet "$svc"; then
    log "  OK: ${svc} is running"
    return 0
  else
    log "  FAIL: ${svc} is NOT running"
    return 1
  fi
}

check_port() {
  local port="$1"
  local desc="$2"
  if ss -tlnp "sport = :${port}" 2>/dev/null | grep -q LISTEN; then
    log "  OK: ${desc} (port ${port}) is listening"
    return 0
  else
    log "  FAIL: ${desc} (port ${port}) is NOT listening"
    return 1
  fi
}

check_disk() {
  local threshold=85
  local usage
  usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
  if [[ "$usage" -lt "$threshold" ]]; then
    log "  OK: Disk usage ${usage}% (threshold ${threshold}%)"
    return 0
  else
    log "  WARN: Disk usage ${usage}% exceeds threshold ${threshold}%"
    return 1
  fi
}

check_memory() {
  local threshold=90
  local usage
  usage=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
  if [[ "$usage" -lt "$threshold" ]]; then
    log "  OK: Memory usage ${usage}% (threshold ${threshold}%)"
    return 0
  else
    log "  WARN: Memory usage ${usage}% exceeds threshold ${threshold}%"
    return 1
  fi
}

check_dashboard() {
  local HTTP_CODE
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k "https://localhost/" 2>/dev/null || true)
  if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
    log "  OK: Dashboard returned HTTP ${HTTP_CODE}"
    return 0
  else
    log "  FAIL: Dashboard returned HTTP ${HTTP_CODE:-unreachable}"
    return 1
  fi
}

check_indexer() {
  local HEALTH
  HEALTH=$(curl -s -k "https://localhost:9200/_cluster/health" 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)
  if [[ "$HEALTH" =~ ^(green|yellow)$ ]]; then
    log "  OK: Indexer cluster health is ${HEALTH}"
    return 0
  else
    log "  FAIL: Indexer cluster health is ${HEALTH:-unreachable}"
    return 1
  fi
}

check_api() {
  local TOKEN
  TOKEN=$(curl -s -u admin:admin -k "https://localhost:55000/security/user/authenticate" 2>/dev/null | jq -r '.data.token // empty' 2>/dev/null || true)
  if [[ -n "$TOKEN" ]]; then
    log "  OK: Wazuh API is responsive"
    return 0
  else
    log "  FAIL: Wazuh API is not responding"
    return 1
  fi
}

main() {
  log "=== Wazuh Health Check Started ==="

  check_service "wazuh-manager" || ((FAILURES++))
  check_service "wazuh-indexer" || ((FAILURES++))
  check_service "wazuh-dashboard" || ((FAILURES++))
  check_service "filebeat" || ((FAILURES++))

  check_port 443 "Dashboard HTTPS" || ((FAILURES++))
  check_port 55000 "Wazuh API" || ((FAILURES++))
  check_port 9200 "Wazuh Indexer" || ((FAILURES++))

  check_disk || true
  check_memory || true

  check_dashboard || ((FAILURES++))
  check_indexer || ((FAILURES++))
  check_api || ((FAILURES++))

  log "=== Health Check Complete ==="
  if [[ $FAILURES -gt 0 ]]; then
    log "RESULT: UNHEALTHY - ${FAILURES} failure(s)"
    exit 1
  else
    log "RESULT: HEALTHY - All checks passed"
    exit 0
  fi
}

main "$@"
