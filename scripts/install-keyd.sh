#!/usr/bin/env bash
set -euo pipefail

base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$base/scripts/configs/common.sh"

case ${1:-} in
  '')
    [[ $# == 0 && $EUID != 0 ]] || die 'Run as a regular user, without sudo.'
    exec sudo bash "$base/scripts/install-keyd.sh" --system
    ;;
  --system)
    [[ $# == 1 && $EUID == 0 ]] || die 'System installation requires root.'
    target=''
    ;;
  --stage)
    [[ $# == 2 && $2 == /* ]] || die 'Pass an absolute staging directory.'
    target=$(realpath -ms -- "$2")
    [[ $target != / ]] || die 'The filesystem root cannot be a staging directory.'
    ;;
  *)
    die 'Usage: install-keyd.sh [--stage ABSOLUTE_DIR]'
    ;;
esac

directory=$target/etc/keyd
destination=$directory/default.conf
profile=$base/config/keyd/numpad.conf
check_components "$destination"
[[ ! -e $destination || -f $destination ]] || die "Expected a regular file: $destination"
[[ -d $directory ]] || install -d -m755 -- "$directory"

temporary=$(mktemp "$directory/.astral-numpad.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT
install -m644 -- "$profile" "$temporary"
keyd check "$temporary"

changed=false
if [[ ! -f $destination ]] || ! cmp -s -- "$temporary" "$destination" ||
  [[ $(stat -c '%u:%a' -- "$destination") != "$EUID:644" ]]; then
  if [[ -f $destination ]]; then
    backup=$(mktemp "$destination.backup-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
    cp --preserve=mode,timestamps -- "$destination" "$backup"
    printf 'Backup: %s\n' "$backup"
  fi
  mv -T -- "$temporary" "$destination"
  changed=true
  printf 'Installed %s\n' "$destination"
fi

if [[ $1 == --system ]]; then
  systemctl enable keyd.service
  if [[ $changed == true ]]; then
    systemctl restart keyd.service
  else
    systemctl start keyd.service
  fi
fi
