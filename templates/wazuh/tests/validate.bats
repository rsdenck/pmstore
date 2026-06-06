#!/usr/bin/env bats

setup() {
  load '/usr/lib/bats-support/load'
  load '/usr/lib/bats-assert/load'
}

@test "validate script fails when services are down" {
  skip "Integration test - requires container with Wazuh installed"
}

@test "validate script passes when all services are healthy" {
  skip "Integration test - requires container with Wazuh installed"
}

@test "validate script checks API availability" {
  run grep -q "validate_api" /opt/lxchub/templates/wazuh/validate.sh
  assert_success
}

@test "validate script checks PMTUI registration" {
  run grep -q "validate_pmtui" /opt/lxchub/templates/wazuh/validate.sh
  assert_success
}

@test "validate script logs to /var/log/lxchub" {
  run grep -q "LXCHUB_LOG_DIR" /opt/lxchub/templates/wazuh/validate.sh
  assert_success
}
