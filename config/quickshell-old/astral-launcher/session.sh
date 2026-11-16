#!/usr/bin/env bash
set -euo pipefail
umask 077
launcher_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Fail closed: anything other than an idle lock state counts as locked.
locked() { [[ $(astral-lock privacy 2>/dev/null || true) != idle ]]; }
case ${1:-} in close|close-active|toggle|daemon|'') ;; *) set -- toggle "$@" ;; esac
action=${1:-toggle}
case $action in
  close-active)
    # Super+Q is inert while the session is locked or the lock is still starting.
    if locked; then exit 0; fi
    # Close the topmost overlay first: session menu, clipboard, wallpaper
    # selector, launcher, then window.
    session_result=$(astral-session close-active 2>/dev/null || true)
    [[ $session_result != closed ]] || exit 0
    clipboard_result=$(astral-clipboard close-active 2>/dev/null || true)
    [[ $clipboard_result != closed ]] || exit 0
    wallpaper_result=$(astral-wallpaper close-active)
    [[ $wallpaper_result != closed ]] || exit 0
    overview_result=$(astral-overview close-active 2>/dev/null || true)
    [[ $overview_result != closed ]] || exit 0
    shortcuts_result=$(astral-shortcuts close-active 2>/dev/null || true)
    [[ $shortcuts_result != closed ]] || exit 0
    # Never close a background app when the launcher cannot answer safely.
    instances=$(timeout 2 qs list -j -p "$launcher_dir")
    # Quickshell 0.3.2 prints this message even with --json when none exist.
    absent=$(printf 'No running instances for "%s/shell.qml"\nUse --all to list all instances.' "$launcher_dir")
    [[ $instances != "$absent" ]] || instances='[]'
    count=$(jq -er 'if type == "array" then length else error("Invalid instance list") end' <<< "$instances")
    if [[ $count == 0 ]]; then
      exec hyprctl dispatch 'hl.dsp.window.close()'
    fi
    result=$(timeout 2 qs ipc -p "$launcher_dir" call launcher closeActive)
    case $result in
      closed) ;;
      inactive) exec hyprctl dispatch 'hl.dsp.window.close()' ;;
      *) printf 'Cannot safely determine whether the launcher is visible.\n' >&2; exit 1 ;;
    esac
    ;;
  close)
    # Closing a panel must never start a launcher process.
    timeout 2 qs ipc -p "$launcher_dir" call launcher close >/dev/null 2>&1 || true
    ;;
  toggle|daemon)
    : "${XDG_RUNTIME_DIR:?A Wayland user runtime directory is required}"
    # The lock owns the session: a locked or starting lock never opens the launcher.
    if [[ $action == toggle ]] && locked; then exit 0; fi
    # Serialize requests for this configuration, including concurrent first use.
    key=$(printf '%s' "$launcher_dir" | sha256sum)
    exec 9>"$XDG_RUNTIME_DIR/astral-launcher-${key%% *}.start"
    flock -w 10 9
    current=$(timeout 2 qs ipc -p "$launcher_dir" call launcher state 2>/dev/null || true)
    if [[ $current != ready && $current != loading ]]; then
      qs -d -n -p "$launcher_dir" 9>&-
    fi
    for ((attempt = 0; attempt < 40; attempt++)); do
      current=$(timeout 1 qs ipc -p "$launcher_dir" call launcher state 2>/dev/null || true)
      if [[ $current == ready ]]; then
        [[ $action != daemon ]] || exit 0
        result=$(timeout 2 qs ipc -p "$launcher_dir" call launcher toggle "${2:-}" 2>/dev/null || true)
        if [[ $result == ok || $result == blocked ]]; then exit 0; fi
        break
      fi
      sleep 0.05
    done
    printf 'Cannot open launcher: the independent launcher did not become ready.\n' >&2
    exit 1
    ;;
  *) printf 'Usage: astral-launcher [monitor|close|close-active|daemon]\n' >&2; exit 2 ;;
esac
