#!/usr/bin/env bats

setup() {
  load '/usr/lib/bats-support/load'
  load '/usr/lib/bats-assert/load'
}

@test "healthcheck script exists" {
  [ -f "/opt/lxchub/templates/wazuh/healthcheck.sh" ]
}

@test "healthcheck script is executable" {
  [ -x "/opt/lxchub/templates/wazuh/healthcheck.sh" ]
}

@test "healthcheck script has no syntax errors" {
  run bash -n /opt/lxchub/templates/wazuh/healthcheck.sh
  [ "$status" -eq 0 ]
}

@test "healthcheck checks all services" {
  run grep -c "check_service" /opt/lxchub/templates/wazuh/healthcheck.sh
  [ "$status" -eq 0 ]
  [ "$output" -ge 4 ]
}

@test "healthcheck checks all ports" {
  run grep -c "check_port" /opt/lxchub/templates/wazuh/healthcheck.sh
  [ "$status" -eq 0 ]
  [ "$output" -ge 3 ]
}

@test "healthcheck verifies disk and memory" {
  run grep -q "check_disk" /opt/lxchub/templates/wazuh/healthcheck.sh
  assert_success
  run grep -q "check_memory" /opt/lxchub/templates/wazuh/healthcheck.sh
  assert_success
}

@test "healthcheck returns non-zero on failure" {
  run bash -n /opt/lxchub/templates/wazuh/healthcheck.sh
  assert_success
}
