#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch shortcuts-test)
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/config" "$runtime/bin" "$runtime/run"
chmod 700 "$runtime/run"
export XDG_RUNTIME_DIR=$runtime/run
export ASTRAL_SHORTCUTS_FIXTURE=$runtime/binds.json

cat > "$runtime/binds.json" <<'JSON'
[
  {"enabled":true,"modmask":64,"key":"Return","dispatcher":"HL.Dispatcher(exec_cmd)","description":"Apps · Terminal"},
  {"enabled":true,"modmask":68,"key":"slash","dispatcher":"HL.Dispatcher(exec_cmd)","description":"Astral · Keyboard shortcuts"},
  {"enabled":true,"modmask":65,"key":"Tab","dispatcher":"HL.Dispatcher(cycle_next)","description":"Windows · Previous window"},
  {"enabled":true,"modmask":72,"key":"left","dispatcher":"HL.Dispatcher(resize)","description":"Windows · Resize left"},
  {"enabled":true,"modmask":0,"key":"XF86AudioMute","dispatcher":"HL.Dispatcher(exec_cmd)","description":"Media · Mute output"},
  {"enabled":true,"modmask":64,"key":"mouse:272","dispatcher":"HL.Dispatcher(drag)","description":"Mouse · Drag window"},
  {"enabled":false,"modmask":64,"key":"X","dispatcher":"HL.Dispatcher(exec_cmd)","description":"Apps · Disabled"},
  {"enabled":true,"modmask":64,"key":"Y","dispatcher":"HL.Dispatcher(exec_cmd)","description":""},
  {"enabled":true,"modmask":64,"key":"Z","dispatcher":"HL.Dispatcher(exec_cmd)","description":"Custom · Something"}
]
JSON

cat > "$runtime/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
exec cat "$ASTRAL_SHORTCUTS_FIXTURE"
MOCK
cat > "$runtime/bin/astral-lock" <<'MOCK'
#!/usr/bin/env bash
if [[ ${1:-} == privacy ]]; then printf 'idle\n'; exit 0; fi
exit 1
MOCK
chmod +x "$runtime/bin/hyprctl" "$runtime/bin/astral-lock"
export PATH="$runtime/bin:$PATH"

cp -a config/quickshell/. "$runtime/config/"
sed 's|../../config/quickshell/|./|g' tests/shortcuts/check.qml > "$runtime/config/check.qml"

mkdir -p "$runtime/run" "$runtime/state" "$runtime/cache"
chmod 700 "$runtime/run"
export XDG_RUNTIME_DIR=$runtime/run XDG_STATE_HOME=$runtime/state XDG_CACHE_HOME=$runtime/cache
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic
timeout 25 qs -p "$runtime/config/check.qml" --no-color > "$runtime/log" 2>&1 \
  || { cat "$runtime/log"; exit 1; }
cat "$runtime/log"
rg -q 'SHORTCUTS_QML_PASS' "$runtime/log" || { printf 'SHORTCUTS_FAIL: QML checks did not pass\n' >&2; exit 1; }
if rg -q 'SHORTCUTS_FAIL|TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign' "$runtime/log"; then
  printf 'SHORTCUTS_FAIL: QML warnings in shortcuts checks\n' >&2
  exit 1
fi
printf 'SHORTCUTS_PASS (logic, settings, live data and content)\n'
