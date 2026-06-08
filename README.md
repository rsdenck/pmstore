# PMStore

[![PMStack](https://cdn.iconscout.com/icon/premium/png-256-thumb/proxmox-logo-icon-svg-download-png-7196884.png?f=webp)](https://pmoflow.pro)

LXC container template catalog for Proxmox VE. Browse 117+ templates at [pmoflow.pro/store](https://pmoflow.pro/store).

## Quick Start

```bash
# Browse the catalog
open https://pmoflow.pro/store

# Deploy any template (example: Hazuh SOC)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/hazuh.sh)"

# Headless deploy with custom resources
IP="192.168.130.10/24" GW="192.168.130.1" HOSTNAME="HAZUH01" \
  var_cpu=2 var_ram=4096 var_disk=16 \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/ct/hazuh.sh)"
```

All templates in the catalog (`scripts/`) follow the same one-liner pattern:

```bash
bash -c "$(curl -fsSL https://pmoflow.pro/scripts/{template}.sh)"
```

## Requirements

- Proxmox VE 8.x
- Rocky Linux 9 container template (`local:vztmpl/rockylinux-9-default_20240912_amd64.tar.xz`)

## Architecture

```
pmstore/
  ct/              # PMStack appliance deploy scripts (PMTUI wizard)
  scripts/         # Community-style install scripts for 117+ templates
  lib/             # PMStack framework modules
  bin/             # Pre-compiled PMTUI wizard binary
  templates/       # Pre-baked appliance templates (coming soon)
  assets/          # Branding and static resources
```

Source: [github.com/rsdenck/pmstore](https://github.com/rsdenck/pmstore)

## PMStack Appliances

SOC-hardened Rocky Linux 9 containers with PMTUI as the default management shell. Each appliance provides:

- PMTUI management console (resource monitoring, service dashboard, network config, logs)
- Automated deploy wizard (interactive TUI or headless text mode)
- SOC hardening (sysctl, unprivileged container, keyctl)
- Static IP enforcement with bridge binding
- No direct bash access -- all operations through PMTUI

| Script | Appliance | Description |
|--------|-----------|-------------|
| `ct/hazuh.sh` | Hazuh | Wazuh SOC platform (indexer, manager, dashboard) |
| `ct/zabbix.sh` | Zabbix | Enterprise monitoring platform |
| `ct/corrot.sh` | Coroot | Observability platform |
| `ct/vault.sh` | Vault | HashiCorp Vault (planned) |
| `ct/suricata.sh` | Suricata | IDS/IPS engine (planned) |
| `ct/zeek.sh` | Zeek | Network analysis (planned) |

## Catalog

All 117+ templates from the store are available as lightweight install scripts in `scripts/`. These are community-scripts-style one-liners that create a container with the specified software pre-installed and configured.

Visit [pmoflow.pro/store](https://pmoflow.pro/store) to browse, filter by category, and generate custom install commands with your resource preferences.

---

[PMStack Documentation](https://pmoflow.pro) | [Template Catalog](https://pmoflow.pro/store) | [GitHub](https://github.com/rsdenck/pmstore)
