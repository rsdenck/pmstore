# PMStack Branding — colors, header, logo
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/core/branding.sh

readonly C_ORANGE="\e[38;2;255;90;0m"
readonly C_ORANGE_DIM="\e[38;2;255;120;40m"
readonly C_GREEN="\e[38;2;0;220;120m"
readonly C_YELLOW="\e[38;2;255;200;0m"
readonly C_RED="\e[38;2;255;70;70m"
readonly C_BLUE="\e[38;2;70;130;255m"
readonly C_CYAN="\e[38;2;0;200;255m"
readonly C_WHITE="\e[38;2;255;255;255m"
readonly C_GRAY="\e[38;2;160;160;160m"
readonly C_RESET="\e[0m"
readonly C_BOLD="\e[1m"

PMSTACK="${C_CYAN}PMSTACK${C_RESET}"
RSDENCK="${C_GREEN}rsdenck${C_RESET}"

header_info() {
  clear
  echo -e "========================================"
  echo -e "  ${C_BOLD}${C_CYAN}PMSTACK CONSOLE${C_RESET}"
  echo -e "  ${C_GREEN}rsdenck${C_RESET}"
  echo -e "========================================"
}

appliance_header() {
  local name="${1:-Appliance}"
  local version="${2:-}"
  local os="${3:-Rocky Linux 9}"
  echo -e "  ${C_BOLD}${C_WHITE}${name}${C_RESET}${version:+ ${C_GRAY}v${version}${C_RESET}}"
  echo -e "  ${C_GRAY}${os} - Hardened${C_RESET}"
  echo -e "========================================"
}
