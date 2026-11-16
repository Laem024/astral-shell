#!/usr/bin/env bash
# Launch configured applications without handing directories to MIME handlers.
set -euo pipefail
kind=${1:?}; path=${2:?}
manager_json=${3:-'["thunar"]'}
terminal_json=${4:-'["kitty"]'}
video_json=${5:-'["haruna"]'}
[[ $path == /* ]] || { echo 'Expected an absolute local path.' >&2; exit 2; }
parse_command() {
  jq -e 'type == "array" and length > 0 and all(.[]; type == "string" and (contains("\u0000") | not)) and .[0] != ""' <<< "$1" >/dev/null || {
    echo 'Application settings must be nonempty command arrays.' >&2; return 2;
  }
  mapfile -d '' -t app < <(jq -j '.[] | ., "\u0000"' <<< "$1")
}
launch() {
  command -v "${app[0]}" >/dev/null 2>&1 || return 1
  # A separate session keeps applications alive when Quickshell reloads.
  # Catch immediate failures (unavailable executable, display or application).
  env --default-signal=INT,TERM,HUP setsid "${app[@]}" "$@" </dev/null >/dev/null 2>&1 &
  local app_pid=$!
  sleep 0.25
  if ! kill -0 "$app_pid" 2>/dev/null; then wait "$app_pid"; else return 0; fi
}
case $kind in
  folder)
    [[ -d $path && -r $path && -x $path ]] || { echo 'The folder is not accessible.' >&2; exit 1; }
    parse_command "$manager_json"
    if launch "$path"; then exit 0; fi
    # A terminal is a fallback only when the configured explorer cannot start.
    parse_command "$terminal_json"
    cd -- "$path"
    launch || { echo 'Neither the configured file manager nor terminal could open this folder.' >&2; exit 1; }
    ;;
  video)
    [[ -r $path && -f $path ]] || { echo 'The video is not accessible.' >&2; exit 1; }
    parse_command "$video_json"
    launch "$path" || { echo 'Could not start the configured video player. Install Haruna or check applications.videoPlayer.' >&2; exit 1; }
    ;;
  file)
    [[ -r $path && -f $path ]] || { echo 'The file is not accessible.' >&2; exit 1; }
    app=(gio open)
    launch "$path" || { echo 'Could not open this file with its default application.' >&2; exit 1; }
    ;;
  *) exit 2;;
esac
