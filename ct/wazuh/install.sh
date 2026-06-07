#!/usr/bin/env bash
set -Eeuo pipefail

LXCHUB_LOG_DIR="/var/log/lxchub"
LXCHUB_LOG="${LXCHUB_LOG_DIR}/install.log"
WAZUH_VERSION="4.14.5"
WAZUH_YUM_REPO="https://packages.wazuh.com/4.x/yum"
WAZUH_KEY_URL="https://packages.wazuh.com/key/GPG-KEY-WAZUH"

mkdir -p "${LXCHUB_LOG_DIR}"
exec > >(tee -a "${LXCHUB_LOG}") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

usage() {
  echo "Usage: $0 {indexer|manager|dashboard} [indexer_ip]"
  echo "  indexer              Install Wazuh Indexer"
  echo "  manager <ip>         Install Wazuh Manager + Filebeat (connect to indexer at <ip>)"
  echo "  dashboard <ip>       Install Wazuh Dashboard (connect to indexer at <ip>)"
  exit 1
}

ROLE="${1:-}"
INDEXER_IP="${2:-}"

if [[ -z "$ROLE" ]]; then
  usage
fi

log "=== Wazuh ${ROLE} Installation Started ==="
log "Version: ${WAZUH_VERSION}"
log "OS: $(. /etc/os-release && echo "${ID} ${VERSION_ID}")"
log "Hostname: $(hostname)"

if [[ $EUID -ne 0 ]]; then
  log "ERROR: Must be run as root"
  exit 1
fi

log "Configuring system prerequisites..."

for pkg in curl tar openssl; do
  command -v "$pkg" &>/dev/null || dnf install -y "$pkg"
done

sysctl -w vm.max_map_count=262144 2>/dev/null || true
sysctl -w fs.file-max=65535 2>/dev/null || true
cat >/etc/sysctl.d/90-wazuh.conf <<'SYSCONF'
vm.max_map_count=262144
fs.file-max=65535
net.ipv4.ip_local_port_range=15000 65535
net.ipv4.tcp_retries2=5
net.core.rmem_default=262144
net.core.rmem_max=262144
net.core.wmem_default=262144
net.core.wmem_max=262144
SYSCONF

setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

setup_wazuh_repo() {
  rpm --import "${WAZUH_KEY_URL}"
  cat >/etc/yum.repos.d/wazuh.repo <<REPO
[wazuh]
gpgcheck=1
gpgkey=${WAZUH_KEY_URL}
name=Wazuh
baseurl=${WAZUH_YUM_REPO}
enabled=1
protect=1
REPO
  # Rocky Linux 9 uses dnf
  dnf -q makecache
}

# ------------------------------------------------------------------
# Generate certificates on indexer node and create shareable archive
# ------------------------------------------------------------------
generate_certificates() {
  log "Generating SSL certificates..."
  local CERT_DIR="/etc/wazuh-indexer/certs"
  mkdir -p "${CERT_DIR}"
  cd "${CERT_DIR}"

  if [[ -f "root-ca.pem" ]]; then
    log "Certificates already exist"
    return 0
  fi

  local MY_IP
  MY_IP=$(hostname -I | awk '{print $1}')

  openssl genrsa -out root-ca-key.pem 2048 2>/dev/null
  openssl req -new -x509 -sha256 -key root-ca-key.pem -subj "/O=Wazuh/OU=Wazuh/CN=CA" -days 3650 -out root-ca.pem 2>/dev/null

  for node in admin node-1; do
    openssl genrsa -out "${node}-key-temp.pem" 2048 2>/dev/null
    openssl pkcs8 -inform PEM -outform PEM -in "${node}-key-temp.pem" -topk8 -nocrypt -out "${node}-key.pem" 2>/dev/null
    openssl req -new -key "${node}-key.pem" -subj "/O=Wazuh/OU=Wazuh/CN=${node}" -out "${node}.csr" 2>/dev/null
    cat >"${node}.ext" <<EXT
subjectAltName = DNS:${node}, DNS:localhost, IP:${MY_IP}, IP:127.0.0.1
EXT
  done

  openssl x509 -req -in admin.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -days 3650 -out admin.pem 2>/dev/null
  openssl x509 -req -in node-1.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -days 3650 -extfile node-1.ext -out node-1.pem 2>/dev/null

  cp node-1.pem node.pem
  cp node-1-key.pem node-key.pem

  rm -f *.csr *.ext *-temp.pem
  chmod 500 "${CERT_DIR}"
  chmod 400 "${CERT_DIR}"/*.pem
  chown -R wazuh-indexer:wazuh-indexer "${CERT_DIR}"

  # Create shareable archive for other nodes
  mkdir -p /tmp/wazuh-certs-dist
  cp root-ca.pem /tmp/wazuh-certs-dist/
  cp admin.pem admin-key.pem /tmp/wazuh-certs-dist/
  cd /tmp/wazuh-certs-dist
  tar czf /tmp/wazuh-certs.tar.gz .
  chmod 644 /tmp/wazuh-certs.tar.gz
  cd /tmp
  rm -rf /tmp/wazuh-certs-dist

  log "Certificates generated. Archive at /tmp/wazuh-certs.tar.gz"
}

# ------------------------------------------------------------------
# Install Wazuh Indexer
# ------------------------------------------------------------------
install_indexer() {
  log "Installing Wazuh Indexer..."

  setup_wazuh_repo
  dnf install -y wazuh-indexer-"${WAZUH_VERSION}"-1

  generate_certificates

  # Also create dashboard/filebeat cert dirs for local use
  mkdir -p /etc/wazuh-dashboard/certs /etc/filebeat/certs
  cp /etc/wazuh-indexer/certs/root-ca.pem /etc/wazuh-dashboard/certs/
  cp /etc/wazuh-indexer/certs/root-ca.pem /etc/filebeat/certs/
  cp /etc/wazuh-indexer/certs/node.pem /etc/wazuh-dashboard/certs/dashboard.pem
  cp /etc/wazuh-indexer/certs/node-key.pem /etc/wazuh-dashboard/certs/dashboard-key.pem
  cp /etc/wazuh-indexer/certs/node.pem /etc/filebeat/certs/filebeat.pem
  cp /etc/wazuh-indexer/certs/node-key.pem /etc/filebeat/certs/filebeat-key.pem
  chmod 500 /etc/wazuh-dashboard/certs /etc/filebeat/certs
  chmod 400 /etc/wazuh-dashboard/certs/* /etc/filebeat/certs/*

  cat >/etc/wazuh-indexer/opensearch.yml <<INDEXERCFG
network.host: "0.0.0.0"
node.name: "node-1"
path.data: /var/lib/wazuh-indexer
path.logs: /var/log/wazuh-indexer
discovery.type: single-node
plugins.security.ssl.http.pemcert_filepath: /etc/wazuh-indexer/certs/node.pem
plugins.security.ssl.http.pemkey_filepath: /etc/wazuh-indexer/certs/node-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.ssl.transport.pemcert_filepath: /etc/wazuh-indexer/certs/node.pem
plugins.security.ssl.transport.pemkey_filepath: /etc/wazuh-indexer/certs/node-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.ssl.http.enabled: true
plugins.security.allow_default_init_securityindex: true
plugins.security.authcz.admin_dn:
  - "CN=admin,OU=Wazuh,O=Wazuh"
plugins.security.nodes_dn:
  - "CN=node-1,OU=Wazuh,O=Wazuh"
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.restapi.roles_enabled:
  - "all_access"
  - "security_rest_api_access"
INDEXERCFG

  systemctl daemon-reload
  systemctl enable wazuh-indexer
  systemctl start wazuh-indexer

  log "Waiting for indexer to start..."
  for i in $(seq 1 30); do
    if systemctl is-active --quiet wazuh-indexer 2>/dev/null; then
      log "Indexer active after ${i}s"
      break
    fi
    sleep 2
  done
  sleep 5

  /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
    -cd /etc/wazuh-indexer/opensearch-security \
    -icl -nhnv \
    -cacert /etc/wazuh-indexer/certs/root-ca.pem \
    -cert /etc/wazuh-indexer/certs/admin.pem \
    -key /etc/wazuh-indexer/certs/admin-key.pem 2>&1 | tail -5 || true

  log "Wazuh Indexer installed"
}

# ------------------------------------------------------------------
# Install Wazuh Manager + Filebeat
# ------------------------------------------------------------------
install_manager() {
  if [[ -z "${INDEXER_IP}" ]]; then
    log "ERROR: indexer_ip required for manager role"
    exit 1
  fi

  log "Installing Wazuh Manager..."

  setup_wazuh_repo
  dnf install -y wazuh-manager-"${WAZUH_VERSION}"-1

  mkdir -p /etc/filebeat/certs
  if [[ -f /tmp/wazuh-certs.tar.gz ]]; then
    tar xzf /tmp/wazuh-certs.tar.gz -C /etc/filebeat/certs/
    chmod 500 /etc/filebeat/certs
    chmod 400 /etc/filebeat/certs/*
  fi

  systemctl daemon-reload
  systemctl enable wazuh-manager
  systemctl start wazuh-manager

  # Filebeat
  dnf install -y filebeat

  curl -so /etc/filebeat/filebeat.yml "https://packages.wazuh.com/4.14/tpl/wazuh/filebeat/filebeat.yml"
  sed -i "s/hosts: \[\".*:9200\"\]/hosts: [\"${INDEXER_IP}:9200\"]/g" /etc/filebeat/filebeat.yml

  filebeat keystore create 2>/dev/null || true
  echo "admin" | filebeat keystore add username --stdin --force 2>/dev/null || true
  echo "admin" | filebeat keystore add password --stdin --force 2>/dev/null || true

  curl -so /etc/filebeat/wazuh-template.json "https://raw.githubusercontent.com/wazuh/wazuh/v${WAZUH_VERSION}/extensions/elasticsearch/7.x/wazuh-template.json"
  chmod go+r /etc/filebeat/wazuh-template.json 2>/dev/null || true

  curl -s "https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.5.tar.gz" | tar -xvz -C /usr/share/filebeat/module/ 2>/dev/null

  systemctl daemon-reload
  systemctl enable filebeat
  systemctl start filebeat

  log "Wazuh Manager + Filebeat installed"
}

# ------------------------------------------------------------------
# Install Wazuh Dashboard
# ------------------------------------------------------------------
install_dashboard() {
  if [[ -z "${INDEXER_IP}" ]]; then
    log "ERROR: indexer_ip required for dashboard role"
    exit 1
  fi

  log "Installing Wazuh Dashboard..."

  setup_wazuh_repo
  dnf install -y wazuh-dashboard-"${WAZUH_VERSION}"-1

  mkdir -p /etc/wazuh-dashboard/certs
  if [[ -f /tmp/wazuh-certs.tar.gz ]]; then
    tar xzf /tmp/wazuh-certs.tar.gz -C /etc/wazuh-dashboard/certs/
    chmod 500 /etc/wazuh-dashboard/certs
    chmod 400 /etc/wazuh-dashboard/certs/*
  fi

  cat >/etc/wazuh-dashboard/opensearch_dashboards.yml <<DASHCFG
server.host: "0.0.0.0"
server.port: 443
server.ssl.enabled: true
server.ssl.certificate: "/etc/wazuh-dashboard/certs/dashboard.pem"
server.ssl.key: "/etc/wazuh-dashboard/certs/dashboard-key.pem"
opensearch.hosts: ["https://${INDEXER_IP}:9200"]
opensearch.ssl.certificateAuthorities: ["/etc/wazuh-dashboard/certs/root-ca.pem"]
opensearch.ssl.verificationMode: certificate
opensearch.username: "kibanaserver"
opensearch.password: "kibanaserver"
DASHCFG

  chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/

  systemctl daemon-reload
  systemctl enable wazuh-dashboard
  systemctl start wazuh-dashboard

  log "Wazuh Dashboard installed"
}

case "$ROLE" in
  indexer)
    install_indexer
    ;;
  manager)
    install_manager
    ;;
  dashboard)
    install_dashboard
    ;;
  *)
    usage
    ;;
esac

log "=== Wazuh ${ROLE} Installation Completed ==="
