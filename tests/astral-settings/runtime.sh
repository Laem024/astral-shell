#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
scratch=$(astral_test_scratch settings)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/config" "$scratch/run" "$scratch/state" "$scratch/cache" "$scratch/bin" "$scratch/home"
chmod 700 "$scratch/run"
cp -a config/quickshell "$scratch/config/"
cp tests/astral-settings/runtime.qml "$scratch/config/quickshell/check.qml"
cat > "$scratch/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$ASTRAL_SETTINGS_FIXTURE/commands"
case "$*" in
  'repl type'*) printf '%s\n' "${ASTRAL_SETTINGS_API_RESULT:-true}" ;;
  '-j monitors all')
    scale=1
    [[ ! -f $ASTRAL_SETTINGS_FIXTURE/trial ]] || scale=1.25
    printf '[{"name":"DP-1","width":1920,"height":1080,"refreshRate":60,"x":0,"y":0,"scale":%s,"transform":0,"bitDepth":8,"availableModes":["1920x1080@60.000"]}]\n' "$scale"
    ;;
  'eval '*hl.monitor*)
    if [[ $* == *'scale"]=1.25'* ]]; then
      touch "$ASTRAL_SETTINGS_FIXTURE/trial"
    else rm -f "$ASTRAL_SETTINGS_FIXTURE/trial"; fi
    [[ ! -f $ASTRAL_SETTINGS_FIXTURE/fail ]] || { rm -f "$ASTRAL_SETTINGS_FIXTURE/fail"; exit 1; }
    printf 'ok\n'
    ;;
  'eval '*tap-to-click*)
    if [[ $* == *'tap-to-click"]=true'* ]]; then
      printf 'true' > "$ASTRAL_SETTINGS_FIXTURE/tap"
    else printf 'false' > "$ASTRAL_SETTINGS_FIXTURE/tap"; fi
    printf 'ok\n'
    ;;
  '-j getoption input:touchpad:tap-to-click')
    tap=true
    [[ ! -f $ASTRAL_SETTINGS_FIXTURE/tap ]] || tap=$(cat "$ASTRAL_SETTINGS_FIXTURE/tap")
    printf '{"bool":%s,"set":true}\n' "$tap"
    ;;
  '-j getoption '*) printf '{"bool":true,"int":1,"float":1,"str":"us"}\n' ;;
  *) printf 'ok\n' ;;
esac
MOCK
cat > "$scratch/bin/loginctl" <<'MOCK'
#!/usr/bin/env bash
if [[ -f $ASTRAL_SETTINGS_FIXTURE/locked ]]; then printf 'yes\n'; else printf 'no\n'; fi
MOCK
chmod 755 "$scratch/bin/"*
export HOME=$scratch/home XDG_CONFIG_HOME=$scratch/config XDG_RUNTIME_DIR=$scratch/run XDG_STATE_HOME=$scratch/state XDG_CACHE_HOME=$scratch/cache
export ASTRAL_SETTINGS_FIXTURE=$scratch PATH=$scratch/bin:$PATH
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
if ! astral_test_dbus timeout 30 qs -p "$scratch/config/quickshell/check.qml" --no-color > "$scratch/log" 2>&1; then cat "$scratch/log"; exit 1; fi
if rg 'TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign|is not a type|Cannot assign' "$scratch/log"; then cat "$scratch/log"; exit 1; fi
rg -q ASTRAL_SETTINGS_RUNTIME_PASS "$scratch/log" || { cat "$scratch/log"; exit 1; }
[[ ! -f $scratch/trial ]]
# Missing or unexpected capability replies must keep desktop edits blocked.
cp tests/astral-settings/capabilities.qml "$scratch/config/quickshell/check.qml"
for reply in false ok 'error: true is unavailable'; do
  if ! ASTRAL_SETTINGS_API_RESULT="$reply" astral_test_dbus timeout 15 qs -p "$scratch/config/quickshell/check.qml" --no-color > "$scratch/capabilities-log" 2>&1; then cat "$scratch/capabilities-log"; exit 1; fi
  rg -q ASTRAL_SETTINGS_CAPABILITIES_PASS "$scratch/capabilities-log" || { cat "$scratch/capabilities-log"; exit 1; }
done
# Simulate a daemon crash while a display trial is pending, then restart.
cat > "$scratch/state/astral-shell/astral-settings/display-transaction.json" <<'JOURNAL'
{"version":1,"pending":true,"confirmed":[],"previous":[{"output":"DP-1","disabled":false,"mode":"1920x1080@60.000","scale":1,"position":"0x0","transform":0,"mirror":"","bitdepth":8,"vrr":0,"cm":"srgb"}]}
JOURNAL
touch "$scratch/trial"
cp tests/astral-settings/recovery.qml "$scratch/config/quickshell/check.qml"
if ! astral_test_dbus timeout 15 qs -p "$scratch/config/quickshell/check.qml" --no-color > "$scratch/recovery-log" 2>&1; then cat "$scratch/recovery-log"; exit 1; fi
rg -q ASTRAL_SETTINGS_RECOVERY_PASS "$scratch/recovery-log" || { cat "$scratch/recovery-log"; exit 1; }
jq -e '.pending==false' "$scratch/state/astral-shell/astral-settings/display-transaction.json" >/dev/null
[[ ! -f $scratch/trial ]]

# Apply through production services while preserving unrelated theme and state keys.
mkdir -p "$scratch/config/gtk-3.0" "$scratch/config/kitty"
printf '[Other]\nkeep=true\n[Settings]\ncustom=yes\n' > "$scratch/config/gtk-3.0/settings.ini"
printf 'color0 #123456\nfont_size 12\n' > "$scratch/config/kitty/kitty.conf"
cp tests/astral-settings/apply.qml "$scratch/config/quickshell/check.qml"
if ! astral_test_dbus timeout 15 qs -p "$scratch/config/quickshell/check.qml" --no-color > "$scratch/apply-log" 2>&1; then cat "$scratch/apply-log"; exit 1; fi
rg -q ASTRAL_SETTINGS_APPLY_PASS "$scratch/apply-log" || { cat "$scratch/apply-log"; exit 1; }
# Restore neutral fixture state before checking simultaneous daemon startup.
jq '.input={} | .themes={light:{gtk:"",qt:"",icons:"",cursor:""},dark:{gtk:"",qt:"",icons:"",cursor:""}}' "$scratch/state/astral-shell/astral-settings/state.json" > "$scratch/neutral"
cp "$scratch/neutral" "$scratch/state/astral-shell/astral-settings/state.json"
rm -- "$scratch/locked"
if ! astral_test_dbus timeout 25 bash tests/astral-settings/controller.sh > "$scratch/controller-log" 2>&1; then cat "$scratch/controller-log" "$scratch/daemon.log" "$scratch/open.log"; exit 1; fi
rg -q ASTRAL_SETTINGS_CONTROLLER_PASS "$scratch/controller-log"
printf 'ASTRAL_SETTINGS_RUNTIME_PASS\n'
