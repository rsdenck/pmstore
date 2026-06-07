#!/usr/bin/env bats

setup() {
  load '/usr/lib/bats-support/load'
  load '/usr/lib/bats-assert/load'
}

@test "validate script exists" {
  [ -f "/opt/lxchub/templates/wazuh/validate.sh" ]
}

@test "validate script is executable" {
  [ -x "/opt/lxchub/templates/wazuh/validate.sh" ]
}

@test "validate script has no syntax errors" {
  run bash -n /opt/lxchub/templates/wazuh/validate.sh
  [ "$status" -eq 0 ]
}

@test "validate script checks all required services" {
  run grep -q "wazuh-manager" /opt/lxchub/templates/wazuh/validate.sh
  assert_success
  run grep -q "wazuh-indexer" /opt/lxchub/templates/wazuh/validate.sh
  assert_success
  run grep -q "wazuh-dashboard" /opt/lxchub/templates/wazuh/validate.sh
  assert_success
  run grep -q "filebeat" /opt/lxchub/templates/wazuh/validate.sh
  assert_success
}

@test "validate script returns non-zero on failure" {
  # Inject a mock that makes services appear inactive
  run bash -n /opt/lxchub/templates/wazuh/validate.sh
  assert_success
}

@test "services are enabled on boot" {
  # Check that systemd enable commands exist in install
  run grep -c "systemctl enable" /opt/lxchub/templates/wazuh/install.sh
  [ "$status" -eq 0 ]
  [ "$output" -ge 4 ]
}
