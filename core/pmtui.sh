# PMStack PMTUI — download wizard, install in container
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/core/pmtui.sh

PMTUI_BIN="/tmp/pmtui-wizard"
PMTUI_URL="https://raw.githubusercontent.com/rsdenck/pmstore/main/bin/pmtui-wizard"

download_pmtui_wizard() {
  if [ -x "$PMTUI_BIN" ]; then
    msg_ok "PMTUI wizard ready"
    return 0
  fi
  # Try adjacent paths (cloned repo)
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  if [ -x "${dir}/../bin/pmtui-wizard" ]; then
    cp "${dir}/../bin/pmtui-wizard" "$PMTUI_BIN"
    chmod 755 "$PMTUI_BIN"
    msg_ok "PMTUI wizard found locally"
    return 0
  fi
  if [ -x "${dir}/bin/pmtui-wizard" ]; then
    cp "${dir}/bin/pmtui-wizard" "$PMTUI_BIN"
    chmod 755 "$PMTUI_BIN"
    msg_ok "PMTUI wizard found locally"
    return 0
  fi
  msg_info "Downloading PMTUI wizard..."
  curl -fsSL "$PMTUI_URL" -o "$PMTUI_BIN" || die "Failed to download PMTUI wizard"
  chmod 755 "$PMTUI_BIN"
  msg_ok "PMTUI wizard downloaded ($(stat -c%s "$PMTUI_BIN") bytes)"
}

run_pmtui_deploy() {
  local config_json
  config_json=$("$PMTUI_BIN" --deploy 2>/dev/null)
  if [ -z "$config_json" ]; then
    echo "  Wizard cancelled."
    exit 0
  fi
  echo "$config_json"
}

install_pmtui_container() {
  local ctid="$1"
  exec_lxc "$ctid" mkdir -p /etc/lxchub /var/log/lxchub
  push_lxc "$ctid" "$PMTUI_BIN" /usr/local/bin/pmtui
  exec_lxc "$ctid" chmod 755 /usr/local/bin/pmtui
  exec_lxc "$ctid" bash -c 'echo "/usr/local/bin/pmtui" >> /etc/shells'
  exec_lxc "$ctid" usermod -s /usr/local/bin/pmtui root
}

write_metadata() {
  local ctid="$1" appliance="$2" disk="$3" memory="$4" cores="$5"
  exec_lxc "$ctid" bash -c "cat > /etc/lxchub/metadata.json << 'EOF'
{
  \"appliance\": \"${appliance}\",
  \"deployed\": false,
  \"resources\": {
    \"disk\": ${disk},
    \"memory\": ${memory},
    \"cores\": ${cores}
  }
}
EOF"
}
