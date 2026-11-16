#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
runtime=$(astral_test_scratch launcher-session)
qs_binary=$(command -v qs)
cleanup() {
  "$qs_binary" kill -p "$runtime/config/session.qml" >/dev/null 2>&1 || true
  rm -rf -- "$runtime"
}
trap cleanup EXIT
trap 'printf "Failure at line %s\n" "$LINENO" >&2; cat "$runtime/calls" >&2 2>/dev/null || true; cat "$runtime/"*-log >&2' ERR
mkdir -p "$runtime/config/common" "$runtime/run" "$runtime/bin"
chmod 700 "$runtime/run"
cp -a config/quickshell/common/. "$runtime/config/common/"
cp config/quickshell/{launcher-control.qml,dispatch.sh} "$runtime/config/"
cp tests/applauncher/{session,overlays}.qml "$runtime/config/"
jq '.modules |= map(.path="session.qml")' config/quickshell/settings.json > "$runtime/config/settings.json"
export ASTRAL_SESSION_DIR=$runtime XDG_RUNTIME_DIR=$runtime/run
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
cat > "$runtime/bin/qs" <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == ipc ]]; then
  [[ ! -e $ASTRAL_SESSION_DIR/ipc-fail ]] || exit 1
  if [[ ${5:-} == wallpaper-carousel && -e $ASTRAL_SESSION_DIR/partial-fail ]]; then exit 1; fi
fi
exec "$ASTRAL_REAL_QS" "$@"
MOCK
cat > "$runtime/bin/loginctl" <<'MOCK'
#!/usr/bin/env bash
cat "$ASTRAL_SESSION_DIR/locked"
MOCK
cat > "$runtime/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ASTRAL_SESSION_DIR/window-closes"
MOCK
chmod 755 "$runtime/bin/"*
export ASTRAL_REAL_QS=$qs_binary PATH=$runtime/bin:$PATH
export ASTRAL_LAUNCHER_CONTROLLER=$runtime/config/launcher-control.qml
entry=$runtime/config/session.qml
request() { bash "$runtime/config/dispatch.sh" "$entry" launcher "$@"; }
printf 'no\n' > "$runtime/locked"
printf 'inactive\n' > "$runtime/reply"
request close > "$runtime/close-log" 2>&1
request close-active > "$runtime/absent-log" 2>&1
[[ ! -e $runtime/starts ]]
[[ $(wc -l < "$runtime/window-closes") == 1 ]]
request daemon > "$runtime/daemon-log" 2>&1 &
first=$!
request toggle DP-1 > "$runtime/toggle-log" 2>&1 &
second=$!
request 'HDMI-A-1' > "$runtime/monitor-log" 2>&1 &
third=$!
for pid in "$first" "$second" "$third"; do wait "$pid" || { cat "$runtime/"*-log; exit 1; }; done
[[ $(wc -l < "$runtime/starts") == 1 ]]
rg -qx 'toggle DP-1' "$runtime/calls"
rg -qx 'toggle HDMI-A-1' "$runtime/calls"
request close-active > "$runtime/inactive-log" 2>&1
[[ $(tail -n 9 "$runtime/calls") == $'polkit\nsession\ncarousel\nwallpaper\nbar\nclipboard\noverview\nshortcuts\nlauncher' ]]
[[ $(wc -l < "$runtime/window-closes") == 2 ]]
for owner in astral-launcher astral-bar; do
  ASTRAL_OVERLAY_OWNER=$owner timeout 6 "$qs_binary" -p "$runtime/config/overlays.qml" > "$runtime/overlays-log" 2>&1
  rg -q LAUNCHER_OVERLAYS_PASS "$runtime/overlays-log"
done
# The controller resolves the current registry even if a wrapper has an older entry.
bash "$runtime/config/dispatch.sh" "$runtime/config/stale.qml" launcher toggle DP-2 > "$runtime/registry-log" 2>&1
rg -qx 'toggle DP-2' "$runtime/calls"
printf 'closed\n' > "$runtime/reply"
request close-active > "$runtime/consumed-log" 2>&1
[[ $(wc -l < "$runtime/window-closes") == 2 ]]
printf 'unknown\n' > "$runtime/reply"
if request close-active > "$runtime/unknown-log" 2>&1; then exit 1; fi
printf 'inactive\n' > "$runtime/reply"
for failure in ipc-fail partial-fail; do
  touch "$runtime/$failure"
  if request close-active > "$runtime/$failure-log" 2>&1; then exit 1; fi
  rm "$runtime/$failure"
done
[[ $(wc -l < "$runtime/window-closes") == 2 ]]
for hint in yes unknown ''; do
  printf '%s\n' "$hint" > "$runtime/locked"
  before=$(wc -l < "$runtime/calls")
  request toggle > "$runtime/blocked-log" 2>&1
  request close-active > "$runtime/blocked-close-log" 2>&1
  [[ $(wc -l < "$runtime/calls") == "$before" ]]
  [[ $(wc -l < "$runtime/window-closes") == 2 ]]
done
# Dispatch rejects malformed argument lists before launching QML.
if request daemon DP-1 > "$runtime/arguments-log" 2>&1; then exit 1; fi
printf 'LAUNCHER_SESSION_PASS (concurrent startup, IPC, monitor, privacy, ordered global close, unknown replies)\n'
