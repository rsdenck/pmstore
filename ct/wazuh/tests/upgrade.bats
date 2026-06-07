#!/usr/bin/env bats

setup() {
  load '/usr/lib/bats-support/load'
  load '/usr/lib/bats-assert/load'
}

@test "update script exists" {
  [ -f "/opt/lxchub/templates/wazuh/update.sh" ]
}

@test "update script is executable" {
  [ -x "/opt/lxchub/templates/wazuh/update.sh" ]
}

@test "update script has no syntax errors" {
  run bash -n /opt/lxchub/templates/wazuh/update.sh
  [ "$status" -eq 0 ]
}

@test "update script validates after upgrade" {
  run grep -q "validate.sh" /opt/lxchub/templates/wazuh/update.sh
  [ "$status" -eq 0 ]
}

@test "update script creates backups" {
  run grep -q "BACKUP_DIR" /opt/lxchub/templates/wazuh/update.sh
  [ "$status" -eq 0 ]
}
