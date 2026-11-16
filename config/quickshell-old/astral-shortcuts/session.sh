#!/usr/bin/env bash
set -euo pipefail
umask 077

shortcuts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
help() {
  printf 'Usage: astral-shortcuts [toggle|close|close-active|daemon]\n' >&2
  exit 2
}

# Fail closed: anything other than an idle lock state counts as locked.
locked() { [[ $(astral-lock privacy 2>/dev/null || true) != idle ]]; }

case ${1:-} in close|close-active|toggle|daemon|'') ;; *) help ;; esac
action=${1:-toggle}
case $action in
  close)
    # Closing the panel must never start a process.
    timeout 2 qs ipc -p "$shortcuts_dir" call shortcuts close >/dev/null 2>&1 || true
    ;;
  close-active)
    if ! timeout 2 qs ipc -p "$shortcuts_dir" call shortcuts closeActive 2>/dev/null; then
      instances=$(timeout 2 qs list -j -p "$shortcuts_dir")
      # Quickshell 0.3.2 prints text rather than an empty JSON array here.
      absent=$(printf 'No running instances for "%s/shell.qml"\nUse --all to list all instances.' "$shortcuts_dir")
      [[ $instances != "$absent" ]] || instances='[]'
      if [[ $(jq -er 'if type == "array" then length else error("Invalid instance list") end' <<< "$instances") == 0 ]]; then
        printf 'inactive\n'
      else
        printf 'Cannot safely determine whether the shortcuts panel is visible.\n' >&2
        exit 1
      fi
    fi
    ;;
  toggle|daemon)
    : "${XDG_RUNTIME_DIR:?A Wayland user runtime directory is required}"
    # The lock owns the session: a locked or starting lock never opens the panel.
    if [[ $action == toggle ]] && locked; then exit 0; fi
    # Serialize requests for this configuration, including concurrent first use.
    key=$(printf '%s' "$shortcuts_dir" | sha256sum)
    exec 9>"$XDG_RUNTIME_DIR/astral-shortcuts-${key%% *}.start"
    flock -w 10 9
    current=$(timeout 2 qs ipc -p "$shortcuts_dir" call shortcuts state 2>/dev/null || true)
    if [[ $current != ready && $current != loading ]]; then
      qs -d -n -p "$shortcuts_dir" 9>&-
    fi
    for ((attempt = 0; attempt < 40; attempt++)); do
      current=$(timeout 2 qs ipc -p "$shortcuts_dir" call shortcuts state 2>/dev/null || true)
      if [[ $current == ready ]]; then
        [[ $action != daemon ]] || exit 0
        result=$(timeout 2 qs ipc -p "$shortcuts_dir" call shortcuts toggle "" 2>/dev/null || true)
        [[ $result == ok || $result == blocked ]] && exit 0
        break
      fi
      sleep 0.05
    done
    printf 'Shortcuts panel did not become ready.\n' >&2
    exit 1
    ;;
esac
