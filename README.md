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

**PMTUI** is the default management interface at kernel level (`lxc.init.cmd`).
On first boot, PMTUI runs a setup wizard for network, SSH, and appliance install.

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

## Usage

### Deploy a container

```bash
# Interactive mode
sudo ./lxchub-bootstrap.sh

# Non-interactive with DHCP
sudo ./lxchub-bootstrap.sh --id 200 --hostname wazuh-ct --appliance wazuh --dhcp

# Non-interactive with static IP
sudo ./lxchub-bootstrap.sh --id 201 --hostname zabbix --appliance zabbix --ip 10.0.0.50/24 --gw 10.0.0.1
```

### Default resources per container

| Resource | Default |
|----------|---------|
| Disk     | 8 GB    |
| RAM      | 2 GB    |
| vCPU     | 1 core  |

### First boot

PMTUI starts automatically and runs the setup wizard:

1. Network configuration (DHCP or static IP)
2. Hostname
3. SSH access (root login, public key)
4. Appliance installation

All parameters can be pre-configured via CLI flags for fully automated deployment.

### Management

Inside the container, run:

```bash
pmtui
```

This opens the management menu:
- Service Status
- Restart Services
- Validate Installation
- Health Check
- Update Appliance
- View Logs

## License

Proprietary — PMO Ecosystem
