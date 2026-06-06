# LXCHub

Official LXC template repository for the PMO ecosystem.

Production-ready container templates for Proxmox Virtual Environment (PVE).

## Architecture

Each template is an **Appliance** containing:
- Installation logic
- Validation logic
- Upgrade logic
- PMTUI integration
- Health checks
- Documentation

## Available Templates

| Appliance | Status |
|-----------|--------|
| Wazuh | Active |
| Zabbix | Planned |
| Vault | Planned |
| Proxmox Backup Client | Planned |
| Netbox | Planned |
| Grafana | Planned |
| Prometheus | Planned |
| Loki | Planned |
| Uptime Kuma | Planned |
| Guacamole | Planned |
| Authentik | Planned |
| OpenObserve | Planned |

## Requirements

- Proxmox VE 8.x
- Debian 12 (preferred) or Ubuntu 24.04

## Installation

```bash
pve <appliance-slug>
```

## License

Proprietary — PMO Ecosystem
