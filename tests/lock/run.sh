#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
for file in tests/lock/*.sh config/quickshell/dispatch.sh; do bash -n "$file"; done
if ! command -v qs >/dev/null; then printf 'SKIP: Quickshell is required.\n'; exit 0; fi
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
runtime=$(astral_test_scratch lock-auth)
trap 'result=$?; if (( result != 0 )); then cat "$runtime/log" 2>/dev/null || true; fi; kill "${test_pid:-}" 2>/dev/null || true; rm -rf -- "$runtime"' EXIT
cp -a config/quickshell "$runtime/config"
mkdir -m 700 "$runtime/run"
export XDG_RUNTIME_DIR=$runtime/run XDG_STATE_HOME=$runtime/state XDG_CACHE_HOME=$runtime/cache
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
cp tests/lock/Test*.qml "$runtime/config/astral-lock/"
cp tests/lock/TestHint.qml "$runtime/config/common/SessionHint.qml"
# Replace native backends only in this disposable copy; production has no test
# authentication injection, fake PAM result or unlock IPC.
sed -e 's/PamContext {/TestPam {/' -e 's/WlSessionLock {/TestSessionLock {/' -e 's/WlSessionLockSurface {/TestSurface {/' -e '/id: content/a\        Component.onCompleted: root.testView = content' config/quickshell/astral-lock/LockRoot.qml | sed '$d' > "$runtime/config/astral-lock/LockRoot.qml"
sed 's/Settings.SettingsData/Common.SettingsData/g' tests/lock/auth.inc >> "$runtime/config/astral-lock/LockRoot.qml"
printf '}\n' >> "$runtime/config/astral-lock/LockRoot.qml"
printf 'TestPam 1.0 TestPam.qml\nTestSessionLock 1.0 TestSessionLock.qml\nTestSurface 1.0 TestSurface.qml\n' >> "$runtime/config/astral-lock/qmldir"
sed 's|../../config/quickshell/|./|g' tests/lock/presentation.qml > "$runtime/config/presentation.qml"
for entry in lock.qml presentation.qml lock.qml; do
  timeout 12 qs -p "$runtime/config/$entry" --no-color > "$runtime/log" 2>&1 &
  test_pid=$!
  if [[ $entry == lock.qml ]]; then
    ipc() { timeout 1 qs ipc -p "$runtime/config/lock.qml" "$@"; }
    for ((i=0; i<80; i++)); do
      if [[ $(ipc call lock state 2>/dev/null) == secure ]]; then break; fi
      sleep 0.025
    done
    [[ $(ipc call lock state) == secure ]]
    ipc call lock lock
    [[ $(ipc call lock unlock 2>&1 || true) == 'Function not found.' ]]
    [[ $(ipc prop get lock locked 2>&1 || true) == 'Property not found.' ]]
    printf 'IPC_PASS\n'
  fi
  wait "$test_pid"
  test_pid=''
  cat "$runtime/log"
  rg -q PASS "$runtime/log"
  ! rg -q 'FAIL|ERROR|TypeError|ReferenceError|Binding loop' "$runtime/log"
  if [[ $entry == presentation.qml ]]; then sed -i 's/"animations": true/"animations": false/' "$runtime/config/settings.json"; fi
done
cat > "$runtime/config/preview-check.qml" <<'QML'
import QtQuick
import "astral-lock" as Lock
Lock.LockPreview {
  Timer { interval: 600; running: true; onTriggered: Qt.quit() }
}
QML
timeout 8 qs -p "$runtime/config/preview-check.qml" > "$runtime/log" 2>&1
rg -q 'Configuration Loaded' "$runtime/log"
! rg -q 'ERROR|TypeError|ReferenceError|Binding loop' "$runtime/log"
bash tests/lock/session.sh
bash tests/lock/idle.sh
printf 'LOCK_PASS\n'
