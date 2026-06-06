# CRIAÇÃO DO CATALOGO DE TEMPLATES LXC (PARA PROXMOX - PVE)
--------------------------------------------------------------------------------------------------------------------------------
- GITHUB API TOKEN: (stored in .env, NOT versioned)
- [REDACTED - see .env file]
--------------------------------------------------------------------------------------------------------------------------------
# LXCHub - Template Development Specification

## Overview

LXCHub is the official container template repository for the PMO ecosystem.

Repository:

* GitHub: rsdenck/lxchub
* Website: https://pmoflow.pro/store/
* Platform: Proxmox Virtual Environment (PVE)

LXCHub is inspired by Community Scripts but follows its own architecture, standards and ecosystem integration.

The primary goal is to provide production-ready LXC templates for Proxmox VE environments.

Every template must:

* Be fully automated
* Be reproducible
* Be idempotent
* Be tested
* Include validation routines
* Integrate with PMTUI
* Follow LXCHub standards

---

# Core Architecture

Each template is considered an Appliance.

Examples:

* wazuh
* zabbix
* vault
* proxmox-backup-client
* netbox
* grafana
* prometheus
* loki
* uptime-kuma
* guacamole
* authentik
* openobserve

Each appliance contains:

* Installation logic
* Validation logic
* Upgrade logic
* PMTUI integration
* Documentation

---

# Mandatory PMTUI Integration

Every LXCHub template MUST install PMTUI.

Source:

https://github.com/rsdenck/pmo

Only PMTUI components are required.

The container lifecycle is managed through PMTUI.

The appliance must register itself automatically inside PMTUI.

Example:

PMTUI
├── Application Information
├── Service Status
├── Restart Services
├── Update Application
├── Health Check
├── Logs
├── Backup
└── Diagnostics

PMTUI becomes the default management interface inside every LXCHub container.

---

# Directory Structure

Each application follows:

templates/
└── wazuh/
├── install.sh
├── validate.sh
├── update.sh
├── healthcheck.sh
├── metadata.yaml
├── README.md
└── tests/

---

# metadata.yaml Standard

Required fields:

name:
slug:
version:
author:
description:
website:
repository:
supported_os:
memory_minimum:
disk_minimum:
cpu_minimum:
services:
ports:
healthchecks:
tags:

Example:

name: Wazuh Manager
slug: wazuh
version: latest

supported_os:

* debian-12

memory_minimum: 4096

cpu_minimum: 2

disk_minimum: 30

services:

* wazuh-manager
* filebeat

---

# Supported Operating Systems

Preferred:

* Debian 12
* Debian 13

Allowed:

* Ubuntu 24.04

Avoid:

* EOL systems
* unsupported distributions

---

# Installation Standards

Installation scripts must:

* run non-interactively
* support automation
* support CI validation
* support rollback
* support reruns

Required:

set -Eeuo pipefail

Use:

* bash
* systemctl
* apt
* curl
* jq
* yq

Avoid:

* manual user interaction
* fixed IP assumptions
* hardcoded passwords

---

# Logging Standards

All templates must create:

/var/log/lxchub/

Example:

/var/log/lxchub/install.log
/var/log/lxchub/update.log
/var/log/lxchub/healthcheck.log

---

# Health Check Standards

Every appliance must provide:

healthcheck.sh

Validation examples:

* service status
* open ports
* disk usage
* memory usage
* API validation
* web interface validation

Example:

curl localhost:5601

Expected result:

HTTP 200

---

# Validation Requirements

After installation:

validate.sh

Must verify:

* packages installed
* services active
* ports listening
* API available
* PMTUI available

Template publication is blocked if validation fails.

---

# Testing Requirements

Every template must pass:

## Installation Test

Create container.

Install appliance.

Validate.

Destroy container.

## Reinstallation Test

Install twice.

No errors allowed.

## Upgrade Test

Upgrade package.

Validate functionality.

## Reboot Test

Reboot container.

Validate services.

## Health Test

Execute:

healthcheck.sh

Result must be SUCCESS.

---

# OpenCode CLI Workflow

When creating a new template:

1. Analyze application requirements
2. Generate metadata.yaml
3. Generate install.sh
4. Generate validate.sh
5. Generate update.sh
6. Generate healthcheck.sh
7. Generate README.md
8. Generate tests
9. Execute validation
10. Generate pull request

---

# Proxmox Compatibility Requirements

Templates must support:

* PVE 8.x
* Unprivileged Containers
* Privileged Containers
* Nesting enabled
* DHCP networking
* Static networking

Must never require:

* VM conversion
* manual package installation

---

# Security Requirements

Mandatory:

* least privilege
* systemd service validation
* secure defaults
* no default passwords
* no exposed secrets

Forbidden:

* embedded credentials
* plaintext secrets
* insecure repositories

---

# Wazuh Template Requirements

Repository:

https://github.com/rsdenck/lxchub/tree/main/wazuh

The generated Wazuh appliance must:

Install:

* Wazuh Manager
* Filebeat
* Dashboard
* Indexer

Configure:

* system services
* certificates
* firewall rules
* health checks

Validate:

* HTTPS dashboard
* Wazuh API
* Indexer health
* Manager service

Register automatically inside PMTUI.

---

# Publication Requirements

A template is considered publishable only if:

* installation succeeds
* validation succeeds
* health checks succeed
* PMTUI integration succeeds
* documentation exists
* CI passes

---

# PMOFlow Store Integration

Published templates become available at:

https://pmoflow.pro/store/

Each template page contains:

* Description
* Screenshots
* Requirements
* Installation Command
* Version
* Changelog
* Documentation
* Health Status

---

# Installation Philosophy

One command.

One container.

One appliance.

Zero manual configuration.

All templates must be production-ready from the first boot.

---

# Final Rule

Every LXCHub template is an appliance.

PMTUI is mandatory.

No template can be merged into LXCHub unless:

* installation passes
* validation passes
* health checks pass
* PMTUI integration passes

This rule cannot be bypassed.

