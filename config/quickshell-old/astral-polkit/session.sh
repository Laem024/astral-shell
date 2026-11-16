#!/usr/bin/env bash
set -euo pipefail
umask 077

polkit_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
help() {
  printf 'Usage: astral-polkit [daemon|status|cancel|restart]\n' >&2
  exit 2
}

: "${XDG_RUNTIME_DIR:?A Wayland user runtime directory is required}"
key=$(printf '%s' "$polkit_dir" | sha256sum)
exec 9>"$XDG_RUNTIME_DIR/astral-polkit-${key%% *}.start"
flock -w 10 9

state() { timeout 2 qs ipc -p "$polkit_dir/shell.qml" call polkit state 2>/dev/null || true; }

running() { [[ $(state) == ready ]]; }

instance_present() { timeout 2 qs ipc -p "$polkit_dir/shell.qml" call polkit state >/dev/null 2>&1; }

start_agent() {
  local attempt try
  for attempt in 1 2 3; do
    running && return 0
    # A stale instance may have failed to register while polkitd still holds the
    # old listener. Replace it before retrying.
    if instance_present; then
      qs kill -p "$polkit_dir/shell.qml" >/dev/null 2>&1 || true
      sleep 0.3
    fi
    qs -d -n -p "$polkit_dir/shell.qml" 9>&- || true
    for ((try = 0; try < 80; try++)); do
      running && return 0
      sleep 0.05
    done
    sleep 0.5
  done
  printf 'The Polkit agent did not register.\n' >&2
  return 1
}

case ${1:-daemon} in
  daemon)
    start_agent
    ;;
  status)
    if running; then
      active=$(timeout 2 qs ipc -p "$polkit_dir/shell.qml" call polkit active 2>/dev/null || true)
      [[ $active == true ]] && printf 'active\n' || printf 'ready\n'
    elif timeout 2 qs ipc -p "$polkit_dir/shell.qml" call polkit state >/dev/null 2>&1; then
      printf 'loading\n'
    else
      printf 'inactive\n'
      exit 1
    fi
    ;;
  cancel)
    answer=$(timeout 2 qs ipc -p "$polkit_dir/shell.qml" call polkit cancel 2>/dev/null || true)
    [[ -n $answer ]] || { printf 'The Polkit agent is not running.\n' >&2; exit 1; }
    printf '%s\n' "$answer"
    ;;
  restart)
    qs kill -p "$polkit_dir/shell.qml" >/dev/null 2>&1 || true
    sleep 0.3
    start_agent
    ;;
  *) help ;;
esac
