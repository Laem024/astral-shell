#!/usr/bin/env bash
# Public command dispatch only. Runtime coordination belongs to QML.
set -euo pipefail
entry=${1:?Expected a QML entry}
shift
# Shell startup preserves all existing Quickshell arguments; only this query is intercepted.
if [[ ${1:-} == shell ]]; then
  shift
  if [[ ${1:-} != workspace-count ]]; then exec qs -p "$entry" --no-duplicate "$@"; fi
fi
if [[ ${1:-} == clipboard || ${1:-} == overview || ${1:-} == shortcuts ]]; then
  module=$1
  shift
  action=${1:-toggle}
  argument=${2:-}
  case $module in
    clipboard)
      (( $# <= 2 )) || exit 2
      case $action in open|paste) action=toggle; argument=paste ;; delete) action=toggle; argument=delete ;; toggle|clear|close|close-active|daemon) ;; *) exit 2 ;; esac
      if [[ $action == toggle ]]; then
        argument=${argument:-paste}
        [[ $argument == paste || $argument == delete ]] || exit 2
      else [[ -z $argument ]] || exit 2; fi
      export ASTRAL_CLIPBOARD_ENTRY=$entry ASTRAL_CLIPBOARD_ACTION=$action ASTRAL_CLIPBOARD_MODE=$argument
      ;;
    overview)
      (( $# <= 2 )) || exit 2
      case $action in
        alt-tab) argument=${argument:-next}; [[ $argument == next || $argument == previous ]] || exit 2 ;;
        toggle) ;;
        close|close-active|daemon) [[ -z $argument ]] || exit 2 ;;
        *) exit 2 ;;
      esac
      export ASTRAL_OVERVIEW_ENTRY=$entry ASTRAL_OVERVIEW_ACTION=$action ASTRAL_OVERVIEW_ARGUMENT=$argument
      ;;
    shortcuts)
      (( $# <= 1 )) || exit 2
      case $action in toggle|close|close-active|daemon) ;; *) exit 2 ;; esac
      export ASTRAL_SHORTCUTS_ENTRY=$entry ASTRAL_SHORTCUTS_ACTION=$action
      ;;
  esac
  controller_variable=ASTRAL_${module^^}_CONTROLLER
  exec qs -p "${!controller_variable:-${entry%/*}/$module-control.qml}"
fi
if [[ ${1:-} == lock || ${1:-} == session ]]; then
  module=$1
  shift
  (( $# <= 1 )) || { printf 'Too many session arguments.\n' >&2; exit 2; }
  if [[ $module == lock ]]; then
    action=${1:-lock}
    case $action in lock|privacy|idle|activity|auto-lock|auto-dpms|lid|suspend|auto-suspend|logout|reboot|poweroff) ;; *) printf 'Invalid astral-lock action.\n' >&2; exit 2 ;; esac
    export ASTRAL_LOCK_ENTRY=$entry ASTRAL_LOCK_ACTION=$action
    exec qs -p "${ASTRAL_LOCK_CONTROLLER:-${entry%/*}/lock-control.qml}"
  fi
  action=${1:-toggle}
  case $action in toggle|close|close-active|daemon) ;; *) printf 'Usage: astral-session [toggle|close|close-active|daemon]\n' >&2; exit 2 ;; esac
  export ASTRAL_SESSION_ENTRY=$entry ASTRAL_SESSION_ACTION=$action
  exec qs -p "${ASTRAL_SESSION_CONTROLLER:-${entry%/*}/session-control.qml}"
fi
if [[ ${1:-} == polkit ]]; then
  shift
  action=${1:-daemon}
  case $action in daemon|status|cancel|restart) ;; *) printf 'Usage: astral-polkit [daemon|status|cancel|restart]\n' >&2; exit 2 ;; esac
  (( $# <= 1 )) || exit 2
  export ASTRAL_POLKIT_ENTRY=$entry ASTRAL_POLKIT_ACTION=$action
  exec qs -p "${ASTRAL_POLKIT_CONTROLLER:-${entry%/*}/polkit-control.qml}"
fi
if [[ ${1:-} == launcher ]]; then
  shift
  action=${1:-toggle}
  monitor=''
  case $action in
    toggle) (( $# <= 2 )) || { printf 'Too many launcher arguments.\n' >&2; exit 2; }; monitor=${2:-} ;;
    daemon|close|close-active) (( $# <= 1 )) || { printf 'Unexpected launcher monitor.\n' >&2; exit 2; } ;;
    *) (( $# == 1 )) && [[ $action != -* ]] || { printf 'Invalid launcher arguments.\n' >&2; exit 2; }; monitor=$action; action=toggle ;;
  esac
  export ASTRAL_LAUNCHER_ENTRY=$entry ASTRAL_LAUNCHER_ACTION=$action ASTRAL_LAUNCHER_MONITOR=$monitor
  exec qs -p "${ASTRAL_LAUNCHER_CONTROLLER:-${entry%/*}/launcher-control.qml}"
fi
if [[ ${1:-} == wallpaper ]]; then
  shift
  action=${1:-toggle}
  monitor=${2:-}
  case $action in toggle|carousel|daemon|close|close-active) ;; *) monitor=$action; action=toggle ;; esac
  if (( $# > 2 )); then printf 'Usage: astral-wallpaper [toggle|carousel|daemon|close|close-active] [monitor]\n' >&2; exit 2; fi
  export ASTRAL_WALLPAPER_ENTRY=$entry ASTRAL_WALLPAPER_ACTION=$action ASTRAL_WALLPAPER_MONITOR=$monitor
  controller=${ASTRAL_WALLPAPER_CONTROLLER:-${entry%/*}/wallpaper-control.qml}
  exec qs -p "$controller"
fi
case ${1:-start} in
  start) if (( $# )); then shift; fi; exec qs -p "$entry" --no-duplicate "$@" ;;
  daemon) exec qs -d --no-duplicate -p "$entry" ;;
  close-panels) exec timeout 2 qs ipc -p "$entry" call bar closePanels ;;
  workspace-count)
    settings=${ASTRAL_COMMON_SETTINGS:-${entry%/*}/settings.json}
    count=$(jq -ser 'select(length == 1) | .[0].workspaceCount | select(type == "number" and . >= 1 and . <= 100 and . == floor)' "$settings" 2>/dev/null) || count=10
    printf '%s\n' "$count"
    ;;
  *) printf 'Usage: astral-bar [start|daemon|close-panels|workspace-count]\n' >&2; exit 2 ;;
esac
