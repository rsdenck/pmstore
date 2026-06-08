# PMStack Common — messaging, error handling, spinner
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/core/common.sh

msg_info()  { echo -e "  ${C_BLUE}[*]${C_RESET} $1"; }
msg_ok()    { echo -e "  ${C_GREEN}[+]${C_RESET} $1"; }
msg_warn()  { echo -e "  ${C_YELLOW}[!]${C_RESET} $1"; }
msg_error() { echo -e "  ${C_RED}[-]${C_RESET} $1" >&2; }

set -Eeuo pipefail

catch_errors() {
  trap 'error_handler $? $LINENO' ERR
  trap 'cleanup_exit $?' EXIT
}

error_handler() {
  local exit_code=$1
  local line=$2
  msg_error "Failed at line ${line} (exit ${exit_code})"
  [ ! -z "${CTID:-}" ] && cleanup_ctid
  exit "$exit_code"
}

cleanup_exit() {
  local rc=$?
  trap - ERR EXIT
  [ "$rc" -eq 0 ] && return 0
  [ ! -z "${CTID:-}" ] && cleanup_ctid
  exit "$rc"
}

cleanup_ctid() {
  if pct status "$CTID" &>/dev/null; then
    pct stop "$CTID" 2>/dev/null || true
    pct destroy "$CTID" 2>/dev/null || true
  fi
}

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while ps -p "$pid" &>/dev/null; do
    local temp=${spinstr#?}
    printf "  [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

check_root() {
  [[ $EUID -eq 0 ]] || die "Must run as root"
}

check_pct() {
  command -v pct &>/dev/null || die "pct not found (not a PVE host?)"
}
