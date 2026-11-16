#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
runtime=$(astral_test_scratch wallpaper-session)
qs_binary=$(command -v qs)
cleanup() {
  local id
  while IFS= read -r id; do "$qs_binary" kill --id "$id" >/dev/null 2>&1 || true; done < <("$qs_binary" list --json -p "$runtime/config/session.qml" 2>/dev/null | jq -r '.[]?.id' 2>/dev/null || true)
  rm -rf -- "$runtime"
}
trap cleanup EXIT
trap 'cat "$runtime/"*-log >&2' ERR
mkdir -p "$runtime/config/common" "$runtime/run" "$runtime/bin"
chmod 700 "$runtime/run"
cp -a config/quickshell/common/. "$runtime/config/common/"
cp config/quickshell/{wallpaper-control.qml,dispatch.sh} "$runtime/config/"
cp tests/wallpaper/session.qml "$runtime/config/session.qml"
export ASTRAL_SESSION_DIR=$runtime XDG_RUNTIME_DIR=$runtime/run
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
# Keep the real IPC/instance lock, but allow an explicit transport failure.
cat > "$runtime/bin/qs" <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == ipc ]]; then
  if [[ -f $ASTRAL_SESSION_DIR/ipc-fail || ( ${5:-} == wallpaper-carousel && -f $ASTRAL_SESSION_DIR/carousel-fail ) ]]; then exit 1; fi
fi
exec "$ASTRAL_REAL_QS" "$@"
MOCK
chmod 755 "$runtime/bin/qs"
export ASTRAL_REAL_QS=$qs_binary PATH=$runtime/bin:$PATH
export ASTRAL_WALLPAPER_CONTROLLER=$runtime/config/wallpaper-control.qml
entry=$runtime/config/session.qml
request() { bash "$runtime/config/dispatch.sh" "$entry" wallpaper "$@"; }
request close > "$runtime/close-log" 2>&1
[[ ! -e $runtime/starts ]]
request close-active > "$runtime/inactive-log" 2>&1
rg -q inactive "$runtime/inactive-log"
[[ ! -e $runtime/starts ]]
request daemon > "$runtime/daemon-log" 2>&1 &
first=$!
request toggle DP-1 > "$runtime/toggle-log" 2>&1 &
second=$!
request daemon > "$runtime/second-log" 2>&1 &
third=$!
for pid in "$first" "$second" "$third"; do wait "$pid" || { cat "$runtime/"*-log; exit 1; }; done
[[ $(wc -l < "$runtime/starts") == 1 ]]
[[ $(wc -l < "$runtime/toggles") == 1 ]]
rg -qx 'selector DP-1' "$runtime/toggles"
request carousel DP-2 > "$runtime/carousel-log" 2>&1
rg -qx 'carousel DP-2' "$runtime/toggles"
request 'HDMI-A-1' > "$runtime/monitor-log" 2>&1
rg -qx 'selector HDMI-A-1' "$runtime/toggles"
touch "$runtime/ipc-fail"
if request close-active > "$runtime/failure-log" 2>&1; then exit 1; fi
rg -q 'Cannot safely determine' "$runtime/failure-log"
rm "$runtime/ipc-fail"
touch "$runtime/carousel-fail"
if request close-active > "$runtime/partial-log" 2>&1; then exit 1; fi
rg -q 'Cannot safely determine' "$runtime/partial-log"
# Duplicate daemon attempts may remain as zombies under a container's PID 1.
# Cold absence was checked above; after transport failure close must still avoid startup.
request close > "$runtime/absent-log" 2>&1
[[ $(wc -l < "$runtime/starts") == 1 ]]
printf 'WALLPAPER_SESSION_PASS (real QML controller, concurrent startup, closed daemon, monitor shortcut, close without startup, failed IPC)\n'
