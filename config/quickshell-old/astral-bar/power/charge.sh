#!/usr/bin/env bash
set -euo pipefail
helper=/usr/local/libexec/astral-charge-limit
[[ -f $helper && ! -L $helper && $(stat -c %u "$helper") == 0 && ! -w $helper ]] || {
  supported=false
  for battery in /sys/class/power_supply/*; do
    if [[ -f $battery/charge_control_end_threshold ]]; then supported=true; break; fi
  done
  if [[ $supported == false ]]; then
    printf 'Unavailable: the native driver exposes no charge thresholds; msi-ec needs verification.\n' >&2
  fi
  printf 'Install the root-owned charge helper to authenticate and verify operations.\n' >&2
  exit 1
}
case ${1:-status} in
  status) exec "$helper" status ;;
  apply) [[ $# == 3 ]] && exec pkexec "$helper" apply "$2" "$3" ;;
  disable) [[ $# == 2 ]] && exec pkexec "$helper" disable "$2" ;;
esac
exit 2
