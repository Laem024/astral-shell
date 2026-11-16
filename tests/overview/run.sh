#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch overview-test)
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/config"
cp -a config/quickshell/. "$runtime/config/"
sed 's|../../config/quickshell/|./|g' tests/overview/check.qml > "$runtime/config/check.qml"
mkdir -p "$runtime/run" "$runtime/state" "$runtime/cache"
chmod 700 "$runtime/run"
export XDG_RUNTIME_DIR=$runtime/run XDG_STATE_HOME=$runtime/state XDG_CACHE_HOME=$runtime/cache
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic
timeout 20 qs -p "$runtime/config/check.qml" --no-color > "$runtime/log" 2>&1 \
  || { cat "$runtime/log"; exit 1; }
cat "$runtime/log"
rg -q 'OVERVIEW_QML_PASS' "$runtime/log" || { printf 'OVERVIEW_FAIL: QML checks did not pass\n' >&2; exit 1; }
if rg -q 'OVERVIEW_FAIL|TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign' "$runtime/log"; then
  printf 'OVERVIEW_FAIL: QML warnings in overview checks\n' >&2
  exit 1
fi
printf 'OVERVIEW_PASS (logic and settings)\n'
