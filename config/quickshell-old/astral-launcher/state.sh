#!/usr/bin/env bash
set -euo pipefail
state_root=${XDG_STATE_HOME:-${HOME:?}/.local/state}
[[ $state_root == /* ]] || state_root=${HOME:?}/.local/state
file=$state_root/astral-shell/astral-launcher/state.json
case ${1:-} in
  read)
    if [[ -e $file ]]; then cat -- "$file"; else printf '%s\n' '{"version":1,"favorites":[],"usage":{}}'; fi
    ;;
  write)
    # Keep personal usage private and replace the previous state atomically.
    umask 077
    mkdir -p -- "${file%/*}"
    temporary=$(mktemp "${file}.XXXXXX")
    trap 'rm -f -- "$temporary"' EXIT
    cat > "$temporary"
    mv -f -- "$temporary" "$file"
    ;;
  *) exit 2 ;;
esac
