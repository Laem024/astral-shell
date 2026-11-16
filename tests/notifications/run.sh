#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then
  bash tests/notifications/run-live.sh
  astral_test_dbus -- bash "$0" --isolated; exit $?
fi
runtime=$(astral_test_scratch notifications)
trap 'result=$?; if (( result != 0 )); then cat "$runtime/log"; fi; kill "${shell_pid:-}" "${monitor_pid:-}" 2>/dev/null || true; rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin"; export PATH="$runtime/bin:$PATH"
mkdir "$runtime/run"
sed 's|../../config/quickshell/|./|g' tests/notifications/service.qml > "$runtime/config/test.qml"
export XDG_RUNTIME_DIR="$runtime/run" QT_QPA_PLATFORM=offscreen
qs --path "$runtime/config/test.qml" --no-color > "$runtime/log" 2>&1 &
shell_pid=$!
for ((i=0; i<100; i++)); do
  if gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner org.freedesktop.Notifications | rg -q true; then break; fi
  sleep 0.05
done
gdbus monitor --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications > "$runtime/signals" &
monitor_pid=$!
sleep 0.1
notify() {
  gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify -- Test "$1" folder "$2" '<b>Plain text</b>' "${5:-['open', 'Open']}" "$3" "$4" | sed -E 's/.*uint32 ([0-9]+).*/\1/'
}
check() {
  local result
  result=$(timeout 3 qs --path "$runtime/config/test.qml" ipc call test inspect "$1")
  printf '%s\n' "$result"
  [[ $result == "PASS $1" ]] || { cat "$runtime/log"; exit 1; }
}
close() {
  gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification "$1" >/dev/null
}
check sound-enable
check sound-muted
check sound-late
check sound-restored
first=$(notify 0 First '{}' 0)
check receive
notify "$first" Replaced '{}' 0 >/dev/null
check replace
notify "$first" Replaced '{}' 0 "['open', 'Updated action']" >/dev/null
check action-label
notify 0 Reading '{}' 0 >/dev/null
check reading
dnd=$(notify 0 DND '{}' 0)
check dnd
check lock-start
notify 0 "While locked" '{}' 0 >/dev/null
check lock-notification
transient=$(notify 0 Transient "{'transient': <true>}" 300)
check transient
sleep 0.5
check paused
sleep 0.5
check expired
close "$dnd"
check closed
notify 0 Action '{}' 0 >/dev/null
check action
resident=$(notify 0 Resident "{'resident': <true>}" 0)
check resident
notify 0 Timed '{}' 200 >/dev/null
sleep 0.4
check normal-expired
notify 0 Critical "{'urgency': <byte 2>}" 100 >/dev/null
sleep 0.3
check critical
notify 0 Default '{}' -1 >/dev/null
check default-timeout
notify 0 DefaultAction '{}' 0 "['default', 'Open']" >/dev/null
check default-action
for ((i=0; i<105; i++)); do notify 0 "Bound $i" '{}' 0 >/dev/null; done
check limit
sleep 0.1
rg -q "ActionInvoked.*'open'" "$runtime/signals"
rg -q "NotificationClosed.*uint32 $transient, uint32 1" "$runtime/signals"
rg -q "NotificationClosed.*uint32 $dnd, uint32 3" "$runtime/signals"
rg -q "NotificationClosed.*uint32 $resident, uint32 2" "$runtime/signals"
kill "$shell_pid"
wait "$shell_pid" || true
sed 's|../../config/quickshell/|./|g' tests/notifications/layout.qml > "$runtime/config/test.qml"
qs --path "$runtime/config/test.qml" --no-color >> "$runtime/log" 2>&1 &
shell_pid=$!
for ((i=0; i<100; i++)); do
  kill -0 "$shell_pid" 2>/dev/null || { cat "$runtime/log"; exit 1; }
  if timeout 1 qs --path "$runtime/config/test.qml" ipc call test inspect ready > /dev/null 2>&1; then break; fi
  sleep 0.05
done
notify 0 Layout '{}' 0 > /dev/null
check page
check hide-page
notify 0 'Your file is ready' '{}' 0 "['open', 'Open folder', 'save', 'Save a copy']" > /dev/null
check unread
for edge in top bottom left right; do
  for mode in light dark; do check "$edge-$mode"; done
done
check snapshot
sleep 0.3
if [[ -n ${ASTRAL_NOTIFICATION_SCREENSHOTS:-} ]]; then
  [[ -s $ASTRAL_NOTIFICATION_SCREENSHOTS/history.png && -s $ASTRAL_NOTIFICATION_SCREENSHOTS/popup.png ]]
fi
check quiet-on
check quiet-off
check delete
check clear
check file-preview
sleep 0.1
check file-snapshot
sleep 0.2
if [[ -n ${ASTRAL_NOTIFICATION_SCREENSHOTS:-} ]]; then [[ -s $ASTRAL_NOTIFICATION_SCREENSHOTS/video-popup.png ]]; fi
cat "$runtime/log"
if rg -q 'ERROR|TypeError|ReferenceError|Binding loop' "$runtime/log"; then exit 1; fi
printf 'NOTIFICATIONS_PASS\n'

bash tests/notifications/open.sh
