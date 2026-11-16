#!/usr/bin/env bash
set -euo pipefail
umask 077

overview_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Fail closed: anything other than an idle lock state counts as locked.
locked() { [[ $(astral-lock privacy 2>/dev/null || true) != idle ]]; }
active_address() {
  hyprctl -j activewindow 2>/dev/null | jq -r '.address // ""' 2>/dev/null || true
}
usage() {
  printf 'Usage: astral-overview [alt-tab next|previous|toggle|close|close-active|daemon]\n' >&2
  exit 2
}

case ${1:-} in close|close-active|alt-tab|toggle|daemon|'') ;; *) usage ;; esac
action=${1:-toggle}
case $action in
  close)
    # Closing a view must never start a process.
    timeout 2 qs ipc -p "$overview_dir" call overview close >/dev/null 2>&1 || true
    ;;
  close-active)
    if ! result=$(timeout 2 qs ipc -p "$overview_dir" call overview closeActive 2>/dev/null); then
      instances=$(timeout 2 qs list -j -p "$overview_dir")
      # Quickshell 0.3.2 prints text rather than an empty JSON array here.
      absent=$(printf 'No running instances for "%s/shell.qml"\nUse --all to list all instances.' "$overview_dir")
      [[ $instances != "$absent" ]] || instances='[]'
      if [[ $(jq -er 'if type == "array" then length else error("Invalid instance list") end' <<< "$instances") == 0 ]]; then
        printf 'inactive\n'
      else
        printf 'Cannot safely determine whether the overview is visible.\n' >&2
        exit 1
      fi
      exit 0
    fi
    printf '%s\n' "$result"
    ;;
  alt-tab|toggle|daemon)
    # The lock owns the session: a locked or starting lock never opens the view.
    if [[ $action != daemon ]] && locked; then exit 0; fi
    : "${XDG_RUNTIME_DIR:?A Wayland user runtime directory is required}"
    # Serialize requests for this configuration, including concurrent first use.
    key=$(printf '%s' "$overview_dir" | sha256sum)
    exec 9>"$XDG_RUNTIME_DIR/astral-overview-${key%% *}.start"
    flock -w 10 9
    current=$(timeout 2 qs ipc -p "$overview_dir" call overview state 2>/dev/null || true)
    if [[ $current != ready && $current != loading ]]; then
      qs -d -n -p "$overview_dir" 9>&-
    fi
    for ((attempt = 0; attempt < 40; attempt++)); do
      current=$(timeout 1 qs ipc -p "$overview_dir" call overview state 2>/dev/null || true)
      if [[ $current == ready ]]; then
        [[ $action != daemon ]] || exit 0
        if [[ $action == alt-tab ]]; then
          direction=${2:-next}
          [[ $direction == next || $direction == previous ]] || direction=next
          result=$(timeout 2 qs ipc -p "$overview_dir" call overview altTab "$direction" "$(active_address)" 2>/dev/null || true)
        else
          result=$(timeout 2 qs ipc -p "$overview_dir" call overview toggle "${2:-}" "$(active_address)" 2>/dev/null || true)
        fi
        [[ $result == ok || $result == blocked ]] && exit 0
        break
      fi
      sleep 0.05
    done
    printf 'Overview did not become ready.\n' >&2
    exit 1
    ;;
esac
