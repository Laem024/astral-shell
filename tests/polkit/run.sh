#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
for file in tests/polkit/*.sh config/quickshell/dispatch.sh; do bash -n "$file"; done
if ! command -v qs >/dev/null; then printf 'SKIP: Quickshell is required.\n'; exit 0; fi
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
runtime=$(astral_test_scratch polkit-flow)
cleanup() {
  qs kill -p "$runtime/config/check.qml" >/dev/null 2>&1 || true
  rm -rf -- "$runtime"
}
trap cleanup EXIT
cp -a config/quickshell "$runtime/config"
cp tests/polkit/check.qml "$runtime/config/"
# Preserve dialog lifecycle and visual content while replacing only layer shell.
cp tests/polkit/HeadlessSurface.qml "$runtime/config/astral-polkit/PolkitSurface.qml"
sed -i '/id: root/a\  property alias testSurface: surface.item' "$runtime/config/astral-polkit/PolkitDialog.qml"
mkdir -m 700 "$runtime/run"
export XDG_RUNTIME_DIR=$runtime/run XDG_CACHE_HOME=$runtime/cache XDG_STATE_HOME=$runtime/state
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
output=$(timeout 10 qs -p "$runtime/config/check.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *POLKIT_FLOW_PASS* && $output != *POLKIT_FAIL* ]]
# Exercise the real service IPC with the simulated backend, never a native agent.
ASTRAL_POLKIT_IPC=1 qs -d --no-duplicate -p "$runtime/config/check.qml"
ipc() { qs ipc -p "$runtime/config/check.qml" call "$@"; }
[[ $(ipc polkit registered) == true && $(ipc polkit active) == true ]]
[[ $(ipc polkit state) == ready && $(ipc polkit action) == org.astral.test ]]
ASTRAL_POLKIT_CONTROLLER=$runtime/config/polkit-control.qml bash "$runtime/config/dispatch.sh" "$runtime/config/check.qml" polkit status > "$runtime/status-log"
rg -q active "$runtime/status-log"
[[ $(ipc polkit cancel) == cancelled && $(ipc polkit closeActive) == closed ]]
ipc test deactivate
[[ $(ipc polkit closeActive) == inactive && $(ipc polkit cancel) == inactive ]]
[[ $(ipc polkit state) == ready ]]
ipc test unregister
[[ $(ipc polkit state) == loading && $(ipc polkit registered) == false ]]
qs kill -p "$runtime/config/check.qml"
bash tests/polkit/session.sh
printf 'POLKIT_PASS\n'
