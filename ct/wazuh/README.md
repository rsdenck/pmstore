# Wazuh Manager LXCHub Template

## Description

Wazuh SIEM platform appliance for Proxmox VE. Includes:
- Wazuh Manager
- Wazuh Indexer
- Wazuh Dashboard
- Filebeat

## Requirements

| Resource | Minimum |
|----------|---------|
| Memory | 4096 MB |
| CPU | 2 cores |
| Disk | 30 GB |
| OS | Debian 12 |

## Services

| Service | Port | Description |
|---------|------|-------------|
| Dashboard | 443 | Web interface (HTTPS) |
| API | 55000 | Wazuh REST API |
| Indexer | 9200 | OpenSearch cluster |
| Events | 1514 | Agent event ingestion |
| Registration | 1515 | Agent registration |
| Agents | 1516 | Agent communication |

## Installation

```bash
bash /opt/lxchub/templates/wazuh/install.sh
```

## Validation

```bash
bash /opt/lxchub/templates/wazuh/validate.sh
```

## Health Check

```bash
bash /opt/lxchub/templates/wazuh/healthcheck.sh
```

## Update

```bash
bash /opt/lxchub/templates/wazuh/update.sh
```

## Default Credentials

**CHANGE IMMEDIATELY AFTER INSTALLATION:**
- URL: https://<container-ip>
- User: admin
- Password: admin

## Management

This appliance integrates with PMTUI for lifecycle management.
Run `pmtui` inside the container to access the management interface.
