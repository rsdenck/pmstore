#!/usr/bin/env bash
set -Eeuo pipefail

LXCHUB_LOG_DIR="/var/log/lxchub"
LXCHUB_LOG="${LXCHUB_LOG_DIR}/install.log"
WAZUH_VERSION="4.9.0"
WAZUH_REPO_BASE="https://packages.wazuh.com/4.x"
PMTUI_REPO="https://github.com/rsdenck/pmo.git"
NODE_VERSION="18"

mkdir -p "${LXCHUB_LOG_DIR}"
exec > >(tee -a "${LXCHUB_LOG}") 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "=== Wazuh Appliance Installation Started ==="
log "Version: ${WAZUH_VERSION}"
log "OS: $(. /etc/os-release && echo "${ID} ${VERSION_ID}")"
log "Hostname: $(hostname)"

# ------------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  log "ERROR: This script must be run as root"
  exit 1
fi

if ! command -v curl &>/dev/null; then
  apt-get update && apt-get install -y curl gnupg apt-transport-https software-properties-common
fi

log "Pre-flight checks passed"

# ------------------------------------------------------------------
# System preparation
# ------------------------------------------------------------------
log "Configuring system prerequisites..."

hostnamectl set-hostname wazuh-master

sysctl -w vm.max_map_count=262144
sysctl -w fs.file-max=65535
cat >>/etc/sysctl.d/90-wazuh.conf <<'SYSCONF'
vm.max_map_count=262144
fs.file-max=65535
net.ipv4.ip_local_port_range=15000 65535
net.ipv4.tcp_retries2=5
net.core.rmem_default=262144
net.core.rmem_max=262144
net.core.wmem_default=262144
net.core.wmem_max=262144
SYSCONF

# ------------------------------------------------------------------
# Install Wazuh Indexer
# ------------------------------------------------------------------
install_indexer() {
  log "Installing Wazuh Indexer..."

  curl -s "${WAZUH_REPO_BASE}/keys/GPG-KEY-WAZUH" | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import --batch 2>/dev/null
  chmod 644 /usr/share/keyrings/wazuh.gpg

  echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] ${WAZUH_REPO_BASE}/apt/ stable main" >/etc/apt/sources.list.d/wazuh.list

  apt-get update
  apt-get install -y wazuh-indexer="${WAZUH_VERSION}-1"

  # Generate certificates
  if [[ ! -f /etc/wazuh-indexer/certs/admin.pem ]]; then
    /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh -cd /etc/wazuh-indexer/opensearch-security -icl -nhnv -cacert /etc/wazuh-indexer/certs/ca.pem -cert /etc/wazuh-indexer/certs/admin.pem -key /etc/wazuh-indexer/certs/admin-key.pem || true
  fi

  systemctl daemon-reload
  systemctl enable wazuh-indexer
  systemctl start wazuh-indexer

  log "Wazuh Indexer installed"
}

# ------------------------------------------------------------------
# Install Wazuh Manager
# ------------------------------------------------------------------
install_manager() {
  log "Installing Wazuh Manager..."

  apt-get install -y wazuh-manager="${WAZUH_VERSION}-1"

  systemctl daemon-reload
  systemctl enable wazuh-manager
  systemctl start wazuh-manager

  log "Wazuh Manager installed"
}

# ------------------------------------------------------------------
# Install Wazuh Dashboard
# ------------------------------------------------------------------
install_dashboard() {
  log "Installing Wazuh Dashboard..."

  apt-get install -y wazuh-dashboard="${WAZUH_VERSION}-1"

  # Configure dashboard connection to indexer
  local INDEXER_IP
  INDEXER_IP=$(hostname -I | awk '{print $1}')
  cat >/etc/wazuh-dashboard/opensearch_dashboards.yml <<DASHCFG
server.host: "0.0.0.0"
server.port: 443
server.ssl.enabled: true
server.ssl.certificate: "/etc/wazuh-dashboard/certs/dashboard.pem"
server.ssl.key: "/etc/wazuh-dashboard/certs/dashboard-key.pem"
opensearch.hosts: ["https://${INDEXER_IP}:9200"]
opensearch.ssl.certificateAuthorities: ["/etc/wazuh-dashboard/certs/ca.pem"]
opensearch.ssl.verificationMode: certificate
opensearch.username: "kibanaserver"
opensearch.password: "kibanaserver"
DASHCFG

  systemctl daemon-reload
  systemctl enable wazuh-dashboard
  systemctl start wazuh-dashboard

  log "Wazuh Dashboard installed"
}

# ------------------------------------------------------------------
# Install Filebeat
# ------------------------------------------------------------------
install_filebeat() {
  log "Installing Filebeat..."

  curl -sL "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-oss-7.10.2-amd64.deb" -o /tmp/filebeat.deb
  dpkg -i /tmp/filebeat.deb
  rm -f /tmp/filebeat.deb

  curl -s "${WAZUH_REPO_BASE}/filebeat/wazuh-filebeat-0.4.tar.gz" -o /tmp/wazuh-filebeat.tar.gz
  tar -xzf /tmp/wazuh-filebeat.tar.gz -C /usr/share/filebeat/module/
  rm -f /tmp/wazuh-filebeat.tar.gz

  # Configure Filebeat
  local INDEXER_IP
  INDEXER_IP=$(hostname -I | awk '{print $1}')
  sed -i "s/hosts: \[\"localhost:9200\"\]/hosts: [\"${INDEXER_IP}:9200\"]/g" /etc/filebeat/filebeat.yml
  sed -i 's/username: "elastic"/username: "admin"/g' /etc/filebeat/filebeat.yml
  sed -i 's/password: "changeme"/password: "admin"/g' /etc/filebeat/filebeat.yml

  # Enable and start
  systemctl daemon-reload
  systemctl enable filebeat
  systemctl start filebeat

  log "Filebeat installed"
}

# ------------------------------------------------------------------
# Install PMTUI
# ------------------------------------------------------------------
install_pmtui() {
  log "Installing PMTUI..."

  if command -v pmtui &>/dev/null; then
    log "PMTUI already installed, skipping"
    return 0
  fi

  apt-get install -y git python3 python3-pip python3-venv

  local PMTUI_DIR="/opt/pmtui"
  if [[ ! -d "${PMTUI_DIR}" ]]; then
    git clone --depth=1 "${PMTUI_REPO}" "${PMTUI_DIR}"
  fi

  if [[ -f "${PMTUI_DIR}/install.sh" ]]; then
    bash "${PMTUI_DIR}/install.sh"
  fi

  log "PMTUI installed"
}

# ------------------------------------------------------------------
# Register appliance in PMTUI
# ------------------------------------------------------------------
register_pmtui() {
  log "Registering Wazuh appliance in PMTUI..."

  local REGISTER_DIR="/etc/pmtui/appliances"
  mkdir -p "${REGISTER_DIR}"

  cat >"${REGISTER_DIR}/wazuh.yaml" <<PMTUIREG
name: Wazuh Manager
slug: wazuh
version: ${WAZUH_VERSION}
description: Wazuh SIEM Platform
services:
  - name: wazuh-manager
    display: Wazuh Manager
    type: systemd
  - name: wazuh-indexer
    display: Wazuh Indexer
    type: systemd
  - name: wazuh-dashboard
    display: Wazuh Dashboard
    type: systemd
  - name: filebeat
    display: Filebeat
    type: systemd
healthcheck: /opt/lxchub/templates/wazuh/healthcheck.sh
validate: /opt/lxchub/templates/wazuh/validate.sh
update: /opt/lxchub/templates/wazuh/update.sh
install_date: $(date -Iseconds)
PMTUIREG

  log "Wazuh registered in PMTUI"
}

# ------------------------------------------------------------------
# Configure firewall
# ------------------------------------------------------------------
configure_firewall() {
  log "Configuring firewall rules..."

  if command -v ufw &>/dev/null; then
    ufw allow 443/tcp comment 'Wazuh Dashboard HTTPS'
    ufw allow 55000/tcp comment 'Wazuh API'
    ufw allow 9200/tcp comment 'Wazuh Indexer'
    ufw allow 1514/tcp comment 'Wazuh Agent Events'
    ufw allow 1515/tcp comment 'Wazuh Agent Registration'
    ufw allow 1516/tcp comment 'Wazuh Agent Comms'
    ufw --force enable
  fi

  log "Firewall configured"
}

# ------------------------------------------------------------------
# Main execution
# ------------------------------------------------------------------
main() {
  install_indexer
  install_manager
  install_dashboard
  install_filebeat
  install_pmtui
  register_pmtui
  configure_firewall

  log "=== Wazuh Appliance Installation Completed ==="
  log "Dashboard: https://$(hostname -I | awk '{print $1}')"
  log "API: https://$(hostname -I | awk '{print $1}'):55000"
  log "Default credentials: admin / admin"
  log "CHANGE DEFAULT PASSWORD IMMEDIATELY"
}

main "$@"
