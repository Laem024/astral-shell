#!/usr/bin/env bash
set -euo pipefail

clipboard_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
help() {
  printf 'Usage: astral-clipboard [open|paste|delete|toggle|close|close-active|clear|daemon]\n' >&2
  exit 2
}

# Fail closed: anything other than an idle lock state counts as locked.
locked() { [[ $(astral-lock privacy 2>/dev/null || true) != idle ]]; }

action=${1:-toggle}
mode=${2:-paste}
case $action in
  open|paste) action=toggle; mode=paste ;;
  delete) action=toggle; mode=delete ;;
  toggle) ;;
esac
case $mode in paste|delete) ;; *) help ;; esac

case $action in
  clear)
    bash "$clipboard_dir/state.sh" clear
    # Refresh an open panel if one exists; never start an instance just to clear.
    timeout 2 qs ipc -p "$clipboard_dir/shell.qml" call clipboard refresh >/dev/null 2>&1 || true
    ;;
  close)
    # Closing must never start a clipboard process.
    timeout 2 qs ipc -p "$clipboard_dir/shell.qml" call clipboard close >/dev/null 2>&1 || true
    ;;
  close-active)
    if ! timeout 2 qs ipc -p "$clipboard_dir/shell.qml" call clipboard closeActive 2>/dev/null; then
      instances=$(timeout 2 qs list -j -p "$clipboard_dir")
      # Quickshell 0.3.2 prints text rather than an empty JSON array here.
      absent=$(printf 'No running instances for "%s/shell.qml"\nUse --all to list all instances.' "$clipboard_dir")
      [[ $instances != "$absent" ]] || instances='[]'
      if [[ $(jq -er 'if type == "array" then length else error("Invalid instance list") end' <<< "$instances") == 0 ]]; then
        printf 'inactive\n'
      else
        printf 'Cannot safely determine whether the clipboard is visible.\n' >&2
        exit 1
      fi
    fi
    ;;
  toggle|daemon)
    : "${XDG_RUNTIME_DIR:?A Wayland user runtime directory is required}"
    # The lock owns the session: a locked or starting lock never opens the panel.
    if [[ $action == toggle ]] && locked; then exit 0; fi
    # Serialize requests for this configuration, including concurrent first use.
    key=$(printf '%s' "$clipboard_dir" | sha256sum)
    exec 9>"$XDG_RUNTIME_DIR/astral-clipboard-${key%% *}.start"
    flock -w 10 9
    current=$(timeout 2 qs ipc -p "$clipboard_dir/shell.qml" call clipboard state 2>/dev/null || true)
    if [[ $current != ready && $current != loading ]]; then
      qs -d -n -p "$clipboard_dir/shell.qml" 9>&-
    fi
    for ((attempt = 0; attempt < 80; attempt++)); do
      current=$(timeout 1 qs ipc -p "$clipboard_dir/shell.qml" call clipboard state 2>/dev/null || true)
      if [[ $current == ready ]]; then
        [[ $action != daemon ]] || exit 0
        result=$(timeout 2 qs ipc -p "$clipboard_dir/shell.qml" call clipboard toggle "$mode" 2>/dev/null || true)
        [[ $result == ok || $result == blocked ]] && exit 0
        break
      fi
      sleep 0.05
    done
    printf 'Clipboard history did not become ready.\n' >&2
    exit 1
    ;;
  *) help ;;
esac
