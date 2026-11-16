#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."

fail() { printf 'SDDM greeter test failed: %s\n' "$*" >&2; exit 1; }
command -v sddm-greeter-qt6 >/dev/null 2>&1 || fail 'sddm-greeter-qt6 not found'
command -v journalctl >/dev/null 2>&1 || fail 'journalctl not found'

start=$(date '+%Y-%m-%d %H:%M:%S')
QT_QPA_PLATFORM=offscreen \
QT_QUICK_BACKEND=software \
QT_NO_XDG_DESKTOP_PORTAL=1 \
  timeout 6 sddm-greeter-qt6 --test-mode --theme "$PWD/config/sddm/astral" \
  >/dev/null 2>&1 || true
sleep 1

journal=$(journalctl -b --since "$start" --no-pager 2>/dev/null || true)
[[ -n $journal ]] || { printf 'SDDM greeter test skipped: journal is unavailable.\n'; exit 0; }

printf '%s\n' "$journal" | grep -Fq "Loading file://$PWD/config/sddm/astral/Main.qml" \
  || fail 'the theme was not loaded'
if printf '%s\n' "$journal" | grep -q 'Fallback to embedded theme'; then
  fail 'SDDM fell back to the embedded theme'
fi
errors=$(printf '%s\n' "$journal" \
  | grep -E 'config/sddm/astral.*(Syntax error|TypeError|is not a type|Cannot read property|Binding loop)' || true)
if [[ -n $errors ]]; then
  printf '%s\n' "$errors" >&2
  fail 'QML errors were reported'
fi

echo 'SDDM greeter test: PASS'
