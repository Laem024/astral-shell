#!/usr/bin/env bash
set -euo pipefail
umask 077
power_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state=${XDG_STATE_HOME:-$HOME/.local/state}/astral-shell
runtime=${XDG_RUNTIME_DIR:?A user runtime directory is required}/astral-caffeine
wanted() { [[ -f $state/caffeine && $(cat -- "$state/caffeine") == on ]]; }
effective() {
  local pid
  [[ -f $runtime ]] && read -r pid < "$runtime" && [[ $pid =~ ^[0-9]+$ ]] \
    && kill -0 "$pid" 2>/dev/null && systemctl --user --quiet is-active astral-caffeine.service
}
case ${1:-status} in
  wanted) wanted ;;
  # Fail closed for automatic actions while an enabled service is starting/failing.
  allowed) ! wanted && ! effective ;;
  status)
    if wanted; then printf 'on\n'; else printf 'off\n'; fi
    if effective; then printf 'active\n'; else printf 'inactive\n'; fi
    systemctl --user show astral-caffeine.service --property=LoadState --value 2>/dev/null || printf 'not-found\n'
    ;;
  on|off)
    exec 9>"$XDG_RUNTIME_DIR/astral-caffeine-change.lock"
    flock -n 9 || { printf 'Caffeine: operation pending.\n' >&2; exit 1; }
    mkdir -p -- "$state"
    printf '%s\n' "$1" > "$state/caffeine.tmp"
    mv -- "$state/caffeine.tmp" "$state/caffeine"
    if [[ $1 == on ]]; then
      # Cancellation uses the installed session command, independent of this service.
      astral-lock activity
      systemctl --user start astral-caffeine.service
      for ((i=0; i<50; i++)); do effective && exit 0; sleep 0.1; done
      printf 'Caffeine preference saved, but the service did not confirm inhibitors. See journalctl --user -u astral-caffeine.\n' >&2
      exit 1
    else
      systemctl --user stop astral-caffeine.service
      ! effective
    fi
    ;;
  run)
    wanted || exit 0
    exec systemd-inhibit --what=idle:handle-lid-switch --mode=block --who=astral-caffeine \
      --why='Caffeine: keep processes active and lock when the lid closes' bash "$power_dir/caffeine.sh" hold
    ;;
  hold)
    # systemd-inhibit starts this child only after logind grants both inhibitors.
    printf '%s\n' "$$" > "$runtime"
    trap 'rm -f -- "$runtime"; kill "${sleeper:-}" 2>/dev/null || true' EXIT
    trap 'exit 0' TERM INT
    sleep infinity & sleeper=$!
    wait "$sleeper"
    ;;
  *) printf 'Usage: caffeine.sh [status|wanted|allowed|on|off|run|hold]\n' >&2; exit 2 ;;
esac
