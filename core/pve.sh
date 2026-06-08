# PMStack PVE Helpers — pct operations, template, network
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/core/pve.sh

next_ctid() {
  pvesh get /cluster/nextid 2>/dev/null || die "Cannot get next CT ID"
}

ct_exists() {
  local ctid="$1"
  [[ -f "/etc/pve/lxc/${ctid}.conf" ]]
}

create_lxc() {
  local ctid="$1" template="$2"
  shift 2
  pct create "$ctid" "$template" "$@" &>>"${LOG:-/dev/null}" || die "pct create failed"
}

start_lxc() {
  local ctid="$1"
  pct start "$ctid" &>>"${LOG:-/dev/null}" || die "Failed to start CT $ctid"
}

exec_lxc() {
  local ctid="$1"
  shift
  pct exec "$ctid" -- "$@" &>>"${LOG:-/dev/null}"
}

push_lxc() {
  local ctid="$1" src="$2" dst="$3"
  pct push "$ctid" "$src" "$dst" &>>"${LOG:-/dev/null}"
}

resize_lxc() {
  local ctid="$1" disk="$2"
  pct resize "$ctid" rootfs "${disk}G" &>>"${LOG:-/dev/null}" || true
}

lxc_systemd() {
  local ctid="$1" action="$2" unit="$3"
  exec_lxc "$ctid" systemctl "$action" "$unit"
}
