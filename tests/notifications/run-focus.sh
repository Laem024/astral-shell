#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then
  if [[ -z ${WAYLAND_DISPLAY:-} || -z ${XDG_RUNTIME_DIR:-} ]]; then
    printf 'Run this compositor check from a Wayland session.\n' >&2
    exit 1
  fi
  astral_test_dbus -- bash "$0" --isolated
  exit $?
fi
runtime=$(astral_test_scratch notifications)
trap 'result=$?; if (( result != 0 )); then cat "$runtime/log"; fi; kill "${shell_pid:-}" 2>/dev/null || true; wait "${shell_pid:-}" 2>/dev/null || true; rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin"; export PATH="$runtime/bin:$PATH"
sed 's|../../config/quickshell/|./|g' tests/notifications/focus.qml > "$runtime/config/test.qml"
if [[ $WAYLAND_DISPLAY != /* ]]; then export WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"; fi
mkdir "$runtime/run"
if [[ -d $XDG_RUNTIME_DIR/hypr ]]; then ln -s "$XDG_RUNTIME_DIR/hypr" "$runtime/run/hypr"; fi
export XDG_RUNTIME_DIR="$runtime/run" QT_QPA_PLATFORM=wayland
export QT_QPA_PLATFORMTHEME=basic QT_QUICK_CONTROLS_STYLE=Basic
qs --path "$runtime/config/test.qml" --no-color > "$runtime/log" 2>&1 &
shell_pid=$!
for ((i=0; i<50; i++)); do
  kill -0 "$shell_pid" 2>/dev/null || exit 1
  if timeout 1 qs --path "$runtime/config/test.qml" ipc call test inspect ready >/dev/null 2>&1; then break; fi
  sleep 0.05
done
check() {
  local result
  result=$(timeout 3 qs --path "$runtime/config/test.qml" ipc call test inspect "$1")
  printf '%s\n' "$result"
  [[ $result == "PASS $1" ]]
}
notify() {
  gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify -- Test 0 folder 'Focus regression' 'This must preserve the panel.' '[]' '{}' 0 >/dev/null
  sleep 0.15
}
# Allow all initially transparent surfaces to finish mapping before the test.
sleep 0.3
check ready
notify
check arrival
check open
sleep 0.2
check opened
notify
check panel
check hidden
notify
check panel
check quiet
cat "$runtime/log"
if rg -q 'ERROR|TypeError|ReferenceError|Binding loop' "$runtime/log"; then exit 1; fi
printf 'NOTIFICATIONS_FOCUS_PASS\n'
