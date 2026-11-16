#!/usr/bin/env bash
# Exercise production QML controllers with literal-argument mock system tools.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch session-control)
trap 'rm -rf -- "$runtime"' EXIT
trap 'printf "Controller check failed at line %s\n" "$LINENO" >&2; cat "$runtime/"*-log >&2' ERR
qs_binary=$(command -v qs)
cp -a config/quickshell "$runtime/config"
mkdir -p "$runtime/bin" "$runtime/run"
chmod 700 "$runtime/run"
# Use the explicit entry fallback, including a path containing shell syntax.
jq '.modules=[]' "$runtime/config/settings.json" > "$runtime/settings"
mv "$runtime/settings" "$runtime/config/settings.json"
sed -i 's/property int startupTimeout: 6000/property int startupTimeout: 600/' "$runtime/config/common/InstanceControl.qml"
export ASTRAL_CONTROL_TEST=$runtime ASTRAL_REAL_QS=$qs_binary XDG_RUNTIME_DIR=$runtime/run
export XDG_STATE_HOME=$runtime/state XDG_CACHE_HOME=$runtime/cache
export ASTRAL_LOCK_CONTROLLER=$runtime/config/lock-control.qml ASTRAL_SESSION_CONTROLLER=$runtime/config/session-control.qml
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
export PATH=$runtime/bin:$PATH
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
cat > "$runtime/bin/qs" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 != -p ]] || exec "$ASTRAL_REAL_QS" "$@"
printf '%s\n' "$@" >> "$ASTRAL_CONTROL_TEST/args"
case $1 in
  -d)
    if [[ $4 == *"literal session"* ]]; then target=session; else target=lock; fi
    echo "$target" >> "$ASTRAL_CONTROL_TEST/starts"
    touch "$ASTRAL_CONTROL_TEST/$target-present"
    exit 0 ;;
  list)
    if [[ $4 == *"literal session"* ]]; then target=session; else target=lock; fi
    if [[ -f $ASTRAL_CONTROL_TEST/$target-present ]]; then echo '[{}]'; else echo '[]'; fi
    exit 0 ;;
  ipc)
    target=$5
    if [[ $target == idle ]]; then
      [[ ! -f $ASTRAL_CONTROL_TEST/cancelled ]] || exit 1
      echo true; exit
    fi
    [[ -f $ASTRAL_CONTROL_TEST/$target-present ]] || exit 1
    case $6 in
      state)
        if [[ -f $ASTRAL_CONTROL_TEST/unknown ]]; then echo strange
        elif [[ $target == lock ]]; then
          if [[ -f $ASTRAL_CONTROL_TEST/locking ]]; then echo locking; else echo secure; fi
        else echo ready; fi ;;
      toggle) echo toggle >> "$ASTRAL_CONTROL_TEST/toggles"; echo ok ;;
      close) echo ok ;;
      closeActive)
        [[ ! -f $ASTRAL_CONTROL_TEST/unknown ]] || { echo strange; exit; }
        echo closed ;;
    esac ;;
esac
MOCK
cat > "$runtime/bin/loginctl" <<'MOCK'
#!/usr/bin/env bash
if [[ -f $ASTRAL_CONTROL_TEST/privacy-unknown ]]; then exit 1; fi
if [[ -f $ASTRAL_CONTROL_TEST/locked ]]; then echo yes; else echo no; fi
MOCK
cat > "$runtime/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$ASTRAL_CONTROL_TEST/power"
[[ ! -f $ASTRAL_CONTROL_TEST/power-fail ]]
MOCK
cat > "$runtime/bin/busctl" <<'MOCK'
#!/usr/bin/env bash
if [[ -f $ASTRAL_CONTROL_TEST/media-error ]]; then exit 1; fi
if [[ $* == *ListInhibitors* ]]; then
  if [[ -f $ASTRAL_CONTROL_TEST/inhibited ]]; then echo '{"data":[[["idle","other","test","block",1000,1]]]}'
  else echo '{"data":[[]]}'; fi
elif [[ $* == *get-property* ]]; then
  if [[ -f $ASTRAL_CONTROL_TEST/playing ]]; then echo 's "Playing"'; else echo 's "Paused"'; fi
else echo org.mpris.MediaPlayer2.test; fi
MOCK
chmod 755 "$runtime/bin/"*
lock_entry="$runtime/literal lock;\$(touch INJECTED).qml"
session_entry="$runtime/literal session.qml"
lock_request() { bash "$runtime/config/dispatch.sh" "$lock_entry" lock "$@"; }
session_request() { bash "$runtime/config/dispatch.sh" "$session_entry" session "$@"; }
lock_request lock > "$runtime/first-log" 2>&1 &
first=$!
lock_request lock > "$runtime/second-log" 2>&1 &
second=$!
wait "$first" "$second"
[[ $(rg -c '^lock$' "$runtime/starts") == 1 ]]
rg -qFx "$lock_entry" "$runtime/args"
[[ ! -f INJECTED ]]
touch "$runtime/locking"
if lock_request suspend > "$runtime/locking-log" 2>&1; then exit 1; fi
[[ ! -f $runtime/power ]]
rm "$runtime/locking"
lock_request suspend > "$runtime/suspend-log" 2>&1
rg -qFx -- --check-inhibitors=yes "$runtime/power"
rg -qFx suspend "$runtime/power"
rm "$runtime/power"
for blocked in playing media-error inhibited cancelled; do
  touch "$runtime/$blocked"
  lock_request auto-suspend > "$runtime/$blocked-log" 2>&1
  [[ ! -f $runtime/power ]]
  rm "$runtime/$blocked"
done
mkdir -p "$runtime/state/astral-shell"
echo on > "$runtime/state/astral-shell/caffeine"
lock_request auto-suspend > "$runtime/caffeine-log" 2>&1
[[ ! -f $runtime/power ]]
echo off > "$runtime/state/astral-shell/caffeine"
lock_request auto-suspend > "$runtime/auto-log" 2>&1
[[ -f $runtime/power ]]
touch "$runtime/power-fail"
if lock_request suspend > "$runtime/failure-log" 2>&1; then exit 1; fi
rm "$runtime/power-fail"
session_request toggle > "$runtime/pending-log" 2>&1
[[ ! -f $runtime/toggles && ! -f $runtime/session-present ]]
rm "$runtime/run/astral-shell/lock-pending"
session_request close > "$runtime/close-log" 2>&1
[[ $(wc -l < "$runtime/starts") == 1 ]]
session_request daemon > "$runtime/daemon-log" 2>&1 &
first=$!
session_request toggle > "$runtime/toggle-log" 2>&1 &
second=$!
wait "$first" "$second"
[[ $(rg -c '^session$' "$runtime/starts") == 1 && $(wc -l < "$runtime/toggles") == 1 ]]
session_request close-active > "$runtime/close-active-log" 2>&1
rg -q closed "$runtime/close-active-log"
for blocked in locked privacy-unknown; do
  touch "$runtime/$blocked"
  session_request toggle > "$runtime/$blocked-log" 2>&1
  [[ $(wc -l < "$runtime/toggles") == 1 ]]
  rm "$runtime/$blocked"
done
touch "$runtime/unknown"
if session_request close-active > "$runtime/unknown-log" 2>&1; then exit 1; fi
if lock_request lock > "$runtime/unknown-lock-log" 2>&1; then exit 1; fi
if session_request invalid > "$runtime/invalid-log" 2>&1; then exit 1; fi
printf 'SESSION_CONTROL_PASS\n'
