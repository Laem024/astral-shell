#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mode=${1:-install}
[[ $# -le 1 ]] || { printf 'Usage: %s [install|update]\n' "$0" >&2; exit 1; }
case $mode in
  install|update) ;;
  *) printf 'Usage: %s [install|update]\n' "$0" >&2; exit 1 ;;
esac

# Start from a clean terminal so earlier commands and package-manager output
# never mix with the installation prompts.
if [[ -t 1 && ${TERM:-} != dumb ]]; then
  printf '\033[H\033[2J'
fi

# Add modules here; invoke them with Bash so they need no executable permission.
bash "$PROJECT_ROOT/scripts/install-packages.sh" "$PROJECT_ROOT" "$mode"
bash "$PROJECT_ROOT/scripts/enable-services.sh"

# Configuration backups are optional. Non-interactive runs keep the default
# (backup enabled) so scripts and tests never wait for input.
declare -a config_options=()
if [[ -t 0 && -t 1 ]]; then
  read -r -p 'Back up existing configurations before applying? [Y/n]: ' backup_answer || backup_answer=Y
  case $backup_answer in
    n|N|no|No|NO)
      config_options=(--no-backup)
      printf 'Proceeding without a configuration backup; matching project files will be overwritten.\n'
      ;;
  esac
fi
if ((${#config_options[@]})); then
  bash "$PROJECT_ROOT/scripts/manage-configs.sh" apply all "${config_options[@]}"
else
  bash "$PROJECT_ROOT/scripts/manage-configs.sh" apply all
fi
bash "$PROJECT_ROOT/scripts/install-sddm.sh" "$mode"
# Power helpers must follow dotfile installation: caffeine cancellation uses it.
bash "$PROJECT_ROOT/scripts/install-power.sh" "$mode"
