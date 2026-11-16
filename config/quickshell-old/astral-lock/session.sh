#!/usr/bin/env bash
set -euo pipefail
umask 077
lock_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
: "${XDG_RUNTIME_DIR:?A Wayland user runtime directory is required}"
display=${WAYLAND_DISPLAY:-wayland-0}
display=${display//[^a-zA-Z0-9_.-]/_}
state=$XDG_RUNTIME_DIR/astral-session-lock-$display
power_dir=$lock_dir/power
allowed() { bash "$power_dir/caffeine.sh" allowed; }
case ${1:-lock} in
  auto-lock)
    allowed || exit 0
    exec bash "$0" lock
    ;;
  auto-dpms)
    allowed || exit 0
    exec hyprctl dispatch dpms off
    ;;
  lid)
    # logind handles the lid normally when caffeine is off.
    if ! allowed; then exec bash "$0" lock; fi
    ;;
  suspend|auto-suspend|logout|reboot|poweroff)
    exec 8>"$state.action"
    flock -n 8 || { printf 'A session action is already pending.\n' >&2; exit 1; }
    case $1 in
      suspend|auto-suspend)
        if [[ $1 == auto-suspend ]]; then allowed || exit 0; fi
        # The independent locker must not inherit the action mutex.
        bash "$0" lock 8>&-
        if [[ $1 == auto-suspend ]]; then
          exec 7>"$XDG_RUNTIME_DIR/astral-caffeine-change.lock"
          flock 7
          allowed || exit 0
        fi
        systemctl --check-inhibitors=yes --no-ask-password suspend
        ;;
      logout)
        : "${HYPRLAND_INSTANCE_SIGNATURE:?Current Hyprland instance is required}"
        hyprctl -i "$HYPRLAND_INSTANCE_SIGNATURE" dispatch 'hl.dsp.exit()'
        ;;
      reboot|poweroff) systemctl --check-inhibitors=yes --no-ask-password "$1" ;;
    esac
    ;;
  privacy)
    if [[ -e $state ]]; then printf 'locked\n'; else printf 'idle\n'; fi
    ;;
  lock)
    # Serialize startup across the key, panel, logind and idle requests.
    exec 9>"$state.start"
    flock 9
    current=$(timeout 2 qs ipc -p "$lock_dir/shell.qml" call lock state 2>/dev/null || true)
    if [[ $current != secure && $current != locking ]]; then
      : > "$state"
      # The child must not inherit the startup mutex.
      qs -d -n -p "$lock_dir/shell.qml" 9>&-
    fi
    flock -u 9
    # A request succeeds only after compositor confirmation, never at spawn time.
    for ((attempt = 0; attempt < 40; attempt++)); do
      if [[ $(timeout 1 qs ipc -p "$lock_dir/shell.qml" call lock state 2>/dev/null) == secure ]]; then exit 0; fi
      sleep 0.05
    done
    printf 'Astral: the compositor has not confirmed the session lock.\n' >&2
    exit 1
    ;;
  idle|activity)
    exec 9>"$state.idle-start"
    flock 9
    if [[ $1 == idle ]]; then
      allowed || exit 0
      qs -d -n -p "$lock_dir/idle.qml" 9>&-
      qs ipc -p "$lock_dir/idle.qml" call idle begin
    else
      qs ipc -p "$lock_dir/idle.qml" call idle cancel 2>/dev/null || true
    fi
    ;;
  *) printf 'Usage: astral-lock [lock|privacy|idle|activity|auto-lock|auto-dpms|lid|suspend|auto-suspend|logout|reboot|poweroff]\n' >&2; exit 2 ;;
esac
