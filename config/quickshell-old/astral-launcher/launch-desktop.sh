#!/usr/bin/env bash
set -euo pipefail
# gtk-launch exits before the application. Its children must not inherit a
# Quickshell pipe that closes on exit: a later diagnostic can cause SIGPIPE.
errors=$(mktemp)
trap 'rm -f -- "$errors"' EXIT
if "$@" </dev/null >/dev/null 2>"$errors"; then
  exit 0
else
  result=$?
  cat -- "$errors" >&2
  exit "$result"
fi
