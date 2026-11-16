#!/usr/bin/env bash
set -euo pipefail
# Arguments come from DesktopEntry.command and Astral settings, never eval/Exec.
directory=$1
shift
[[ -z $directory ]] || cd -- "$directory"
(( $# > 0 )) && command -v -- "$1" >/dev/null || { printf 'Configured terminal executable is unavailable.\n' >&2; exit 1; }
# Accept the request once its executable and working directory are validated.
# Disconnect streams so the terminal can outlive the request and the bar.
"$@" </dev/null >/dev/null 2>&1 &
