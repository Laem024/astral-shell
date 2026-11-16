#!/usr/bin/env bash
set -euo pipefail

bar_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case ${1:-start} in
  start)
    shift
    exec qs -p "$bar_dir/shell.qml" --no-duplicate "$@"
    ;;
  daemon)
    exec qs -d -n -p "$bar_dir/shell.qml"
    ;;
  close-panels)
    exec timeout 2 qs ipc -p "$bar_dir/shell.qml" call bar closePanels
    ;;
  workspace-count)
    count=$(jq -er '.workspaceCount
      | select(type == "number" and . >= 1 and . <= 100 and . == floor)' \
      "$bar_dir/settings.json" 2>/dev/null) || count=10
    printf '%s\n' "$count"
    ;;
  *)
    printf 'Usage: astral-bar [start|daemon|close-panels|workspace-count]\n' >&2
    exit 2
    ;;
esac
