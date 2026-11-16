#!/usr/bin/env bash
set -euo pipefail
umask 077
wallpaper_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Fail closed: anything other than an idle lock state counts as locked.
locked() { [[ $(astral-lock privacy 2>/dev/null || true) != idle ]]; }
case ${1:-} in close|close-active|dismiss-others|toggle|daemon|carousel|'') ;; *) set -- toggle "$@" ;; esac
action=${1:-toggle}
case $action in
  close)
    timeout 2 qs ipc -p "$wallpaper_dir" call wallpaper close >/dev/null 2>&1 || true
    timeout 2 qs ipc -p "$wallpaper_dir" call wallpaper-carousel close >/dev/null 2>&1 || true
    ;;
  close-active)
    if ! panel=$(timeout 2 qs ipc -p "$wallpaper_dir" call wallpaper closeActive 2>/dev/null); then
      instances=$(timeout 2 qs list -j -p "$wallpaper_dir")
      # Quickshell 0.3.2 prints text rather than an empty JSON array here.
      absent=$(printf 'No running instances for "%s/shell.qml"\nUse --all to list all instances.' "$wallpaper_dir")
      [[ $instances != "$absent" ]] || instances='[]'
      if [[ $(jq -er 'if type == "array" then length else error("Invalid instance list") end' <<< "$instances") == 0 ]]; then
        printf 'inactive\n'
      else
        printf 'Cannot safely determine whether the wallpaper selector is visible.\n' >&2
        exit 1
      fi
      exit 0
    fi
    [[ $panel != closed ]] || exit 0
    carousel=$(timeout 2 qs ipc -p "$wallpaper_dir" call wallpaper-carousel closeActive 2>/dev/null || true)
    [[ $carousel != closed ]] || exit 0
    printf 'inactive\n'
    ;;
  dismiss-others)
    astral-bar close-panels >/dev/null 2>&1 || true
    astral-launcher close
    astral-clipboard close >/dev/null 2>&1 || true
    astral-session close >/dev/null 2>&1 || true
    astral-overview close >/dev/null 2>&1 || true
    astral-shortcuts close >/dev/null 2>&1 || true
    ;;
  toggle|daemon|carousel)
    # The lock owns the session: a locked or starting lock never opens an overlay.
    if [[ $action != daemon ]] && locked; then exit 0; fi
    : "${XDG_RUNTIME_DIR:?A Wayland user runtime directory is required}"
    key=$(printf '%s' "$wallpaper_dir" | sha256sum)
    exec 9>"$XDG_RUNTIME_DIR/astral-wallpaper-${key%% *}.start"
    flock -w 10 9
    current=$(timeout 2 qs ipc -p "$wallpaper_dir" call wallpaper state 2>/dev/null || true)
    if [[ $current != ready && $current != loading ]]; then
      qs -d -n -p "$wallpaper_dir" 9>&-
    fi
    for ((attempt = 0; attempt < 80; attempt++)); do
      current=$(timeout 1 qs ipc -p "$wallpaper_dir" call wallpaper state 2>/dev/null || true)
      if [[ $current == ready ]]; then
        [[ $action != daemon ]] || exit 0
        target=wallpaper
        [[ $action != carousel ]] || target=wallpaper-carousel
        result=$(timeout 2 qs ipc -p "$wallpaper_dir" call "$target" toggle "${2:-}" 2>/dev/null || true)
        [[ $result == ok || $result == blocked ]] && exit 0
        break
      fi
      sleep 0.05
    done
    printf 'Wallpaper service did not become ready.\n' >&2; exit 1
    ;;
  *) printf 'Usage: astral-wallpaper [monitor|carousel|close|close-active|dismiss-others] or astral-wallpaper-daemon\n' >&2; exit 2 ;;
esac
