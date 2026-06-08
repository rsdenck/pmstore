# PMStore

[![PMStack](https://cdn.iconscout.com/icon/premium/png-256-thumb/proxmox-logo-icon-svg-download-png-7196884.png?f=webp)](https://pmoflow.pro)

Production-ready LXC appliance templates for Proxmox VE, powered by the PMStack framework.

## Overview

PMStore is a curated catalog of pre-built Rocky Linux 9 containers purpose-built for infrastructure workloads. Each appliance ships with **PMTUI** as the default management shell -- a terminal-based control interface for day-2 operations, monitoring, and configuration.

## Appliances

| Appliance | Description | Template |
|-----------|-------------|----------|
| hazuh     | Wazuh SOC platform (indexer, manager, dashboard) | `template/hazuh/rocky9_hazuh_amd64.tar.xz` |
| zabbix    | Zabbix monitoring platform | `template/zabbix/rocky9_zabbix_amd64.tar.xz` |
| corrot    | Coroot observability platform | `template/corrot/rocky9_corrot_amd64.tar.xz` |

## Quick Deploy

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/hazuh.sh)"
```

For headless/automated deployments:

```bash
export IP="192.168.130.10/24" GW="192.168.130.1" HOSTNAME="HAZUH01"
export var_cpu=2 var_ram=4096 var_disk=16
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/hazuh.sh)"
```

## Requirements

- Proxmox VE 8.x
- Rocky Linux 9 container template (`local:vztmpl/rockylinux-9-default_20240912_amd64.tar.xz`)

## Architecture

```
pmstore/
  ct/              # Deploy scripts (appliance wrappers)
  core/            # PMStack framework (modular shell libraries)
  bin/             # Pre-compiled PMTUI wizard binary
  template/        # Pre-baked appliance templates
    hazuh/
    zabbix/
    corrot/
  assets/          # Branding and static resources
```

## PMTUI Management Console

All appliances use PMTUI as the system shell. When you SSH into a container or open its console, PMTUI starts automatically, providing:

- System resource monitoring (CPU, RAM, disk, network)
- Service health dashboard with appliance-aware filtering
- Network configuration (static IP, DNS, gateway)
- System logs viewer
- Security hardening controls
- SOC-hardened defaults

No bash access is exposed to the user -- all management is done through the PMTUI interface.

## Deploy Wizard

The PMTUI deploy wizard handles the full provisioning lifecycle:

1. Container creation (pct create with resource allocation)
2. Root password initialization
3. DNS configuration
4. SSH setup (configurable port, disable option)
5. PMTUI installation and shell registration
6. Metadata writing
7. SOC hardening (sysctl, kernel parameters)
8. Network finalization (static IP assignment, hostname, tags)

Supports both interactive TUI mode and headless text mode for automation.

## Security

- Unprivileged containers with keyctl and nesting features
- SOC-inspired sysctl hardening (syncookies, rp_filter, IPv6 RA/redirect disable)
- PMTUI-only access model (no direct shell)
- Static IP enforcement with bridge binding

---

[PMStack Documentation](https://pmoflow.pro) | [GitHub](https://github.com/rsdenck/pmstore)
