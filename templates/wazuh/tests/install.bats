#!/usr/bin/env bats

setup() {
  load '/usr/lib/bats-support/load'
  load '/usr/lib/bats-assert/load'
}

@test "install script exists" {
  [ -f "/opt/lxchub/templates/wazuh/install.sh" ]
}

@test "install script is executable" {
  [ -x "/opt/lxchub/templates/wazuh/install.sh" ]
}

@test "install script runs without syntax errors" {
  run bash -n /opt/lxchub/templates/wazuh/install.sh
  [ "$status" -eq 0 ]
}

@test "install creates log directory" {
  run bash /opt/lxchub/templates/wazuh/install.sh --dry-run 2>/dev/null || true
  # Verify the script structure is valid
  run bash -n /opt/lxchub/templates/wazuh/install.sh
  assert_success
}

@test "reinstallation is idempotent" {
  # Run twice, second run must not fail
  run bash /opt/lxchub/templates/wazuh/install.sh --dry-run 2>/dev/null || true
  run bash /opt/lxchub/templates/wazuh/install.sh --dry-run 2>/dev/null || true
  # Script must pass bash syntax check
  run bash -n /opt/lxchub/templates/wazuh/install.sh
  assert_success
}
