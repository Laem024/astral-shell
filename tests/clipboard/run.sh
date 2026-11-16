#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch clipboard-test)
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/config" "$runtime/run" "$runtime/cache" "$runtime/state"
chmod 700 "$runtime/run"
cp -a config/quickshell/. "$runtime/config/"
sed 's|../../config/quickshell/|./|g' tests/clipboard/check.qml > "$runtime/config/check.qml"
export XDG_RUNTIME_DIR=$runtime/run XDG_STATE_HOME=$runtime/state XDG_CACHE_HOME=$runtime/cache
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic
timeout 20 qs -p "$runtime/config/check.qml" --no-color > "$runtime/log" 2>&1 || { cat "$runtime/log"; exit 1; }
cat "$runtime/log"
rg -q CLIPBOARD_QML_PASS "$runtime/log"
bash tests/clipboard/service.sh
printf 'CLIPBOARD_PASS\n'
