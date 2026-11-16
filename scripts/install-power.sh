#!/usr/bin/env bash
# Shared power setup: copied helpers, services and the reviewed MSI fallback.
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$base/scripts/configs/common.sh"
copy_file() {
  local mode=$1 source=$2 destination=$3 backup
  check_components "$destination"
  if [[ -e $destination ]]; then
    [[ -f $destination ]] || die "Expected a regular file: $destination"
    if cmp -s -- "$source" "$destination" && [[ $(stat -c %a "$destination") == "$mode" ]] \
      && [[ $EUID != 0 || $(stat -c %u "$destination") == 0 ]]; then return; fi
    backup=$(mktemp "$destination.backup-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
    cp --preserve=mode,timestamps -- "$destination" "$backup"
    printf 'Backup: %s\n' "$backup"
  fi
  install -Dm"$mode" -- "$source" "$destination"
}
usage() { printf 'Usage: install-power.sh [install|update] | --stage ABSOLUTE_DIR | --user | --system\n'; }
case ${1:-install} in
  install|update)
    [[ $# -le 1 && $EUID != 0 ]] || { usage; exit 2; }
    bash "$base/scripts/install-power.sh" --user
    sudo bash "$base/scripts/install-power.sh" --system
    bash "$base/scripts/install-msi-ec.sh" "${1:-install}"
    exit
    ;;
  --stage)
    [[ $# == 2 && $2 == /* && $2 != / ]] || { usage; exit 2; }
    target=$2
    ;;
  --user)
    [[ $# == 1 && $EUID != 0 ]] || { usage; exit 2; }
    for file in "$base/config/quickshell/common/"*; do
      copy_file 644 "$file" "$HOME/.local/lib/astral-shell/common/${file##*/}"
    done
    copy_file 644 "$base/system/power/astral-caffeine.service" "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/astral-caffeine.service"
    systemctl --user daemon-reload
    systemctl --user enable astral-caffeine.service
    systemctl --user set-environment "XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}" "XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}"
    systemctl --user restart astral-caffeine.service
    exit
    ;;
  --system)
    [[ $# == 1 && $EUID == 0 ]] || { usage; exit 2; }
    target=''
    ;;
  *) usage; exit 2 ;;
esac
# Every privileged executable and all parent directories are owned by root in
# --system mode. Never install a symlink back to this writable repository.
for directory in /usr/local/libexec /etc/systemd/system /etc/udev/rules.d /usr/lib/systemd/system-sleep /usr/share/polkit-1/actions; do
  check_components "$target$directory"
  install -d -m755 -- "$target$directory"
done
copy_file 755 "$base/system/power/astral-charge-limit" "$target/usr/local/libexec/astral-charge-limit"
copy_file 755 "$base/system/power/astral-charge-resume" "$target/usr/lib/systemd/system-sleep/astral-charge-resume"
copy_file 644 "$base/system/power/astral-charge-limit.service" "$target/etc/systemd/system/astral-charge-limit.service"
copy_file 644 "$base/system/power/90-astral-charge-limit.rules" "$target/etc/udev/rules.d/90-astral-charge-limit.rules"
copy_file 644 "$base/system/power/org.astral.shell.charge.policy" "$target/usr/share/polkit-1/actions/org.astral.shell.charge.policy"
if [[ $1 == --stage ]]; then
  for file in "$base/config/quickshell/common/"*; do
    copy_file 644 "$file" "$target/user/.local/lib/astral-shell/common/${file##*/}"
  done
  copy_file 644 "$base/system/power/astral-caffeine.service" "$target/user/.config/systemd/user/astral-caffeine.service"
else
  systemctl daemon-reload
  systemctl enable astral-charge-limit.service
  udevadm control --reload
fi
