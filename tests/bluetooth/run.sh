#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch bluetooth)
trap 'rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin"; export PATH="$runtime/bin:$PATH"
sed 's|../../config/quickshell/|./|g' tests/bluetooth/service.qml > "$runtime/config/bluetooth-test.qml"
# Cover BlueZ replies and state events independently, plus the legacy wording.
for mode in reply event legacy; do
  : > "$runtime/commands"
  output=$(BLUETOOTH_DISCONNECT_MODE="$mode" BLUETOOTH_FIXTURE_LOG="$runtime/commands" XDG_RUNTIME_DIR="$runtime" PATH="$PWD/tests/bluetooth:$PATH" QT_QPA_PLATFORM=offscreen WAYLAND_DISPLAY= timeout 20 qs --path "$runtime/config/bluetooth-test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
  printf '%s\n' "$output"
  [[ $output == *BLUETOOTH_PASS* && $output != *BLUETOOTH_FAIL* ]]
  [[ $(rg -c '^pair ' "$runtime/commands") == 1 ]]
  [[ $(rg -c '^connect ' "$runtime/commands") == 2 ]]
  ! rg -q '123456' "$runtime/commands"
done
