# PMStore - Container & VM Templates

Official template repository for **PMStack** ecosystem.

Documentation: https://pmoflow.pro/

## Directory Structure

```
pmstore/
  ct/          # LXC container templates
    wazuh/     # Wazuh appliance (indexer, manager, dashboard)
    pmtui/     # PMTUI management interface
  vm/          # VM templates (future)
```

## PMStack

PMStack is a Proxmox-based infrastructure stack providing production-ready appliances with PMTUI as the default management interface.

## Requirements

- Proxmox VE 8.x
- Rocky Linux 9 (containers)

## Containers

| CT  | Hostname | IP             | Appliance     |
|-----|----------|----------------|---------------|
| 110 | HAZUH    | 192.168.130.10 | Wazuh All-in-One |

## Management

All containers use **PMTUI** as the default shell (console + SSH).

## Deploy

```bash
var_cpu="2" var_ram="4096" var_disk="16" bash -c "$(curl -fsSL https://raw.githubusercontent.com/rsdenck/pmstore/main/proxmox-ve.sh)"
```
