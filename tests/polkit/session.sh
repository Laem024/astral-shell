#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch polkit-session)
trap 'rm -rf -- "$runtime"' EXIT
trap 'printf "Polkit session failed at line %s\n" "$LINENO" >&2; cat "$runtime/"*-log >&2' ERR
qs_binary=$(command -v qs)
mkdir -p "$runtime/bin" "$runtime/run" "$runtime/config"
chmod 700 "$runtime/run"
cp -a config/quickshell/common "$runtime/config/"
cp config/quickshell/{polkit-control.qml,dispatch.sh} "$runtime/config/"
export ASTRAL_POLKIT_TEST=$runtime XDG_RUNTIME_DIR=$runtime/run
export XDG_CACHE_HOME=$runtime/cache XDG_STATE_HOME=$runtime/state
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
export ASTRAL_POLKIT_CONTROLLER=$runtime/config/polkit-control.qml
export ASTRAL_REAL_QS=$qs_binary
cat > "$runtime/bin/qs" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 != -p ]] || exec "$ASTRAL_REAL_QS" "$@"
printf '%s\n' "$@" >> "$ASTRAL_POLKIT_TEST/args"
case $1 in
  -d)
    echo start >> "$ASTRAL_POLKIT_TEST/starts"
    touch "$ASTRAL_POLKIT_TEST/present"
    date +%s%3N > "$ASTRAL_POLKIT_TEST/start-time"
    exit 0 ;;
  kill)
    echo kill >> "$ASTRAL_POLKIT_TEST/kills"
    rm -f "$ASTRAL_POLKIT_TEST/present"
    exit 0 ;;
  list)
    if [[ -f $ASTRAL_POLKIT_TEST/present ]]; then echo '[{}]'; else echo '[]'; fi
    exit 0 ;;
  ipc)
    [[ -f $ASTRAL_POLKIT_TEST/hang ]] && { sleep 5; exit 1; }
    [[ -f $ASTRAL_POLKIT_TEST/present ]] || exit 1
    case $6 in
      state)
        [[ ! -f $ASTRAL_POLKIT_TEST/unknown ]] || { echo strange; exit; }
        started=$(cat "$ASTRAL_POLKIT_TEST/start-time")
        now=$(date +%s%3N)
        if [[ -f $ASTRAL_POLKIT_TEST/fail ]] || (( now - started < 250 )); then echo loading
        elif [[ -f $ASTRAL_POLKIT_TEST/active ]]; then echo active
        else echo ready; fi ;;
      active) if [[ -f $ASTRAL_POLKIT_TEST/active ]]; then echo true; else echo false; fi ;;
      cancel) echo cancelled ;;
    esac ;;
esac
MOCK
chmod 755 "$runtime/bin/qs"
export PATH=$runtime/bin:$PATH
entry="$runtime/literal path;\$(touch INJECTED).qml"
request() { bash "$runtime/config/dispatch.sh" "$entry" polkit "$@"; }
request daemon > "$runtime/first-log" 2>&1 &
first=$!
request daemon > "$runtime/second-log" 2>&1 &
second=$!
wait "$first" "$second"
[[ $(wc -l < "$runtime/starts") == 1 ]]
request status > "$runtime/status-log" 2>&1
rg -q ready "$runtime/status-log"
touch "$runtime/active"
request status > "$runtime/active-log" 2>&1
rg -q active "$runtime/active-log"
request cancel > "$runtime/cancel-log" 2>&1
rg -q cancelled "$runtime/cancel-log"
# A preexisting instance still registering gets a full readiness window.
date +%s%3N > "$runtime/start-time"
request status > "$runtime/preexisting-loading-log" 2>&1
rg -q loading "$runtime/preexisting-loading-log"
request daemon > "$runtime/late-existing-log" 2>&1
[[ ! -f $runtime/kills ]]
request restart > "$runtime/restart-log" 2>&1
[[ $(wc -l < "$runtime/starts") == 2 && $(wc -l < "$runtime/kills") == 1 ]]
rg -qFx "$entry" "$runtime/args"
[[ ! -f INJECTED ]]
touch "$runtime/unknown"
if request daemon > "$runtime/unknown-log" 2>&1; then exit 1; fi
[[ $(wc -l < "$runtime/kills") == 1 ]]
rm "$runtime/unknown" "$runtime/present"
if request status > "$runtime/absent-log" 2>&1; then exit 1; fi
rg -q inactive "$runtime/absent-log"
if request cancel > "$runtime/no-cancel-log" 2>&1; then exit 1; fi
# Registration failure exhausts exactly three starts, then releases the lock.
touch "$runtime/fail"
if request daemon > "$runtime/fail-log" 2>&1; then exit 1; fi
[[ $(wc -l < "$runtime/starts") == 5 ]]
rg -q 'did not register' "$runtime/fail-log"
request status > "$runtime/loading-log" 2>&1
rg -q loading "$runtime/loading-log"
rm "$runtime/fail"
request daemon > "$runtime/recover-log" 2>&1
# A hung IPC child is bounded by Common.Command's deadline.
touch "$runtime/hang"
if request status > "$runtime/hang-log" 2>&1; then exit 1; fi
rm "$runtime/hang"
if request unknown > "$runtime/arguments-log" 2>&1; then exit 1; fi
if request daemon extra > "$runtime/extra-log" 2>&1; then exit 1; fi
printf 'POLKIT_SESSION_PASS\n'
