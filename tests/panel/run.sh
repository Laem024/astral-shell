#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE

source tests/xdg-scratch.sh
runtime=$(astral_test_scratch panel-test)
trap 'rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/home/.config" "$runtime/run"
chmod 700 "$runtime/run"
sed 's|../../config/quickshell/|./|g' tests/panel/state.qml > "$runtime/config/test.qml"

export HOME="$runtime/home"
export XDG_CONFIG_HOME="$runtime/home/.config"
export XDG_RUNTIME_DIR="$runtime/run"
export XDG_STATE_HOME="$runtime/state" XDG_CACHE_HOME="$runtime/cache"
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software
export QT_QUICK_CONTROLS_STYLE=Basic

output=$(timeout 20 qs -p "$runtime/config/test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *PANEL_QML_PASS* && $output != *PANEL_FAIL* ]]
if rg -q 'TypeError|ReferenceError|Binding loop|Failed to load configuration' <<< "$output"; then
  exit 1
fi
