#!/usr/bin/env bash
# Native Quickshell integration with disposable files and mocked hardware tools.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
command -v qs >/dev/null || { printf 'SKIP: qs is unavailable.\n'; exit 0; }
if [[ ${1:-} != --isolated ]]; then
  if ! astral_test_dbus -- true >/dev/null 2>&1; then
    printf 'SKIP: runtime integration needs permission to create local D-Bus/IPC sockets.\n'
    exit 0
  fi
  astral_test_dbus -- bash "$0" --isolated; exit $?
fi
scratch=$(astral_test_scratch runtime-test)
qs_binary=$(command -v qs)
cleanup() {
  local entry
  while IFS= read -r -d '' entry; do "$qs_binary" kill -p "$entry" >/dev/null 2>&1 || true; done < <(find "$scratch" -name '*.qml' -print0)
  rm -rf -- "$scratch"
}
trap cleanup EXIT
cp -a config/quickshell "$scratch/config"
mkdir -p "$scratch/bin" "$scratch/run" "$scratch/home" "$scratch/state" "$scratch/cache" "$scratch/pictures" "$scratch/videos"
chmod 700 "$scratch/run"
export HOME=$scratch/home XDG_CONFIG_HOME=$scratch XDG_RUNTIME_DIR=$scratch/run XDG_STATE_HOME=$scratch/state XDG_CACHE_HOME=$scratch/cache
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
export ASTRAL_FIXTURE=$scratch
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
printf 'no\n' > "$scratch/locked"
printf 'a2dp-sink\n' > "$scratch/profile"
cat > "$scratch/bin/loginctl" <<'MOCK'
#!/usr/bin/env bash
cat "$ASTRAL_FIXTURE/locked"
MOCK
cat > "$scratch/bin/xdg-user-dir" <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == PICTURES ]]; then printf '%s/pictures\n' "$ASTRAL_FIXTURE"; else printf '%s/videos\n' "$ASTRAL_FIXTURE"; fi
MOCK
cat > "$scratch/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
if [[ -f $ASTRAL_FIXTURE/disconnected ]]; then printf '[]\n'; else printf '[{"name":"eDP-1","x":0,"y":0,"width":1920,"height":1080,"scale":1,"transform":0}]\n'; fi
MOCK
cat > "$scratch/bin/slurp" <<'MOCK'
#!/usr/bin/env bash
# Like slurp, consume optional input boxes before opening the selector.
cat >/dev/null
[[ ! -f $ASTRAL_FIXTURE/cancel-selection ]] || exit 1
printf '10,20 100x200\n'
MOCK
cat > "$scratch/bin/grim" <<'MOCK'
#!/usr/bin/env bash
[[ ! -f $ASTRAL_FIXTURE/fail-shot ]] || { printf 'Simulated screenshot failure.\n' >&2; exit 1; }
printf 'image\n' > "${@: -1}"
MOCK
cat > "$scratch/bin/wf-recorder" <<'MOCK'
#!/usr/bin/env -S --default-signal=INT bash
while (( $# )); do if [[ $1 == -f ]]; then file=$2; shift; fi; shift; done
trap 'printf "finalized\n" >> "$file"; printf "finalized\n" >> "$ASTRAL_FIXTURE/events"; exit 0' INT
printf 'header\n' > "$file"
printf 'recording\n' >> "$ASTRAL_FIXTURE/events"
while :; do sleep 0.05; done
MOCK
cat > "$scratch/bin/pactl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ASTRAL_FIXTURE/audio-events"
case "$*" in
  get-default-sink) printf 'alsa_output.fixture\n' ;;
  get-default-source)
    if [[ -f $ASTRAL_FIXTURE/bluetooth ]]; then printf 'bluez_input.41:42:FF:98:CD:17\n'; else printf 'alsa_input.fixture\n'; fi ;;
  'get-source-mute '*) printf 'Mute: no\n' ;;
  '--format=json list cards') printf '[{"name":"bluez_card.41_42_FF_98_CD_17","active_profile":"%s"}]\n' "$(cat "$ASTRAL_FIXTURE/profile")" ;;
  '--format=json list sources') printf '[{"name":"bluez_input.41:42:FF:98:CD:17","index":1}]\n' ;;
  '--format=json list source-outputs') printf '[]\n' ;;
  '--format=json list sinks') printf '[{"name":"alsa_output.fixture"}]\n' ;;
  'set-card-profile '*) printf '%s\n' "$3" > "$ASTRAL_FIXTURE/profile" ;;
  'load-module '*) printf '42\n' ;;
  'unload-module '*) ;;
  *) exit 1 ;;
esac
MOCK
cat > "$scratch/bin/wpctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ASTRAL_FIXTURE/policy-events"
[[ $# != 2 ]] || printf 'Value: true\n'
MOCK
cat > "$scratch/bin/pw-dump" <<'MOCK'
#!/usr/bin/env bash
printf '[]\n'
MOCK
chmod 755 "$scratch/bin/"*
export PATH=$scratch/bin:$PATH
fail() { printf 'QUICKSHELL_RUNTIME_FAIL: %s\n' "$*" >&2; cat "$scratch/"*.log >&2; exit 1; }
ipc() { timeout 3 "$qs_binary" ipc -p "$1" call "${@:2}" 2>/dev/null; }
wait_value() {
  local entry=$1 target=$2 method=$3 expected=$4 result
  for ((attempt=0;attempt<100;attempt++)); do
    result=$(ipc "$entry" "$target" "$method" || true)
    [[ $result != "$expected" ]] || return 0
    sleep 0.1
  done
  fail "Timeout waiting for $target.$method=$expected (received $result)."
}
# External modules use only their entry point; no settings/session helper required.
mkdir -p "$scratch/config/external with spaces"
cat > "$scratch/config/external with spaces/shell.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
  property string nonce: Date.now().toString()
  IpcHandler { target: "fixture"; function status(): string { return "ready"; } }
}
QML
cp "$scratch/config/external with spaces/shell.qml" "$scratch/config/manual.qml"
printf 'invalid qml\n' > "$scratch/config/broken.qml"
jq '.modules=[{id:"external",path:"external with spaces",enabled:true,autostart:true},{id:"manual",path:"manual.qml",enabled:true,autostart:false},{id:"broken",path:"broken.qml",enabled:true,autostart:true}]' "$scratch/config/settings.json" > "$scratch/settings"
cp "$scratch/settings" "$scratch/config/settings.json"
"$qs_binary" -p "$scratch/config/shell.qml" --no-duplicate > "$scratch/orchestrator.log" 2>&1 &
orchestrator=$!
external=$scratch/config/external\ with\ spaces/shell.qml
wait_value "$external" fixture status ready
kill -0 "$orchestrator" || fail 'A broken module stopped the orchestrator.'
if ipc "$scratch/config/manual.qml" fixture status; then fail 'Manual module autostarted.'; fi
# Duplicate launch succeeds without replacing or stopping the existing instance.
timeout 5 "$qs_binary" -p "$external" --no-duplicate > "$scratch/duplicate.log" 2>&1 || fail 'Duplicate prevention failed.'
wait_value "$external" fixture status ready
jq '.modules[0].enabled=false' "$scratch/config/settings.json" > "$scratch/settings"
cp "$scratch/settings" "$scratch/config/settings.json"
for ((attempt=0;attempt<80;attempt++)); do if ! ipc "$external" fixture status >/dev/null; then break; fi; sleep 0.1; done
if ipc "$external" fixture status; then fail 'Disabled owned module did not stop.'; fi
"$qs_binary" kill -p "$scratch/config/shell.qml" >/dev/null
wait "$orchestrator" || true
# Backend harness can disappear without taking the independent recorder with it.
cat > "$scratch/config/check.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
import "astral-bar/data" as Data
import "astral-bar/settings" as Bar
import "common" as Common
ShellRoot {
  Component.onCompleted: { if (typeof Quickshell.inhibitReloadPopup === "function") Quickshell.inhibitReloadPopup(); }
  Connections { target: Quickshell; function onReloadCompleted() { Quickshell.inhibitReloadPopup(); } }
  property string commandResult: "waiting"
  Common.Command { id: missingCommand; timeout: 1000 }
  IpcHandler {
    target: "fixture"
    function missing(): void { missingCommand.run(["astral-nonexistent-test-tool"], code => commandResult = code === 0 ? "unexpected" : "failed"); }
    function commandStatus(): string { return commandResult; }
    function ready(): string { return Data.SessionData.ready ? "ready" : "waiting"; }
    function blocked(): string { return Data.SessionData.blocked ? "yes" : "no"; }
    function position(): string { return Bar.SettingsData.value.position; }
    function capture(kind: string, mode: string, audio: string): string {
      const accepted = Data.CaptureData.prepare(kind, mode, "eDP-1", audio);
      if (accepted) Data.CaptureData.panelHidden();
      return accepted ? "accepted" : "rejected";
    }
    function state(): string { return Data.CaptureData.state; }
    function result(): string { return Data.CaptureData.resultFile; }
    function stop(): void { Data.CaptureData.stop(); }
  }
}
QML
entry=$scratch/config/check.qml
"$qs_binary" -p "$entry" --no-duplicate > "$scratch/backend.log" 2>&1 &
bar=$!
wait_value "$entry" fixture ready ready
wait_value "$entry" fixture blocked no
ipc "$entry" fixture missing >/dev/null
wait_value "$entry" fixture commandStatus failed
# Last valid settings survive a malformed reload and recover on the next edit.
wait_value "$entry" fixture position top
printf '{broken\n' > "$scratch/config/astral-bar/settings.json"
sleep 0.3
wait_value "$entry" fixture position top
jq '.position="right"' config/quickshell/astral-bar/settings.json > "$scratch/config/astral-bar/settings.json"
wait_value "$entry" fixture position right
printf 'unknown\n' > "$scratch/locked"
wait_value "$entry" fixture blocked yes
[[ $(ipc "$entry" fixture capture shot monitor none) == rejected ]] || fail 'Unknown privacy state allowed capture.'
printf 'no\n' > "$scratch/locked"
wait_value "$entry" fixture blocked no
[[ $(ipc "$entry" fixture capture shot monitor none) == accepted ]] || fail 'Screenshot rejected.'
wait_value "$entry" fixture state idle
file=$(ipc "$entry" fixture result)
[[ -s $file && $file == "$scratch/pictures/"* ]] || fail 'Screenshot did not save to Pictures.'
# Successful region screenshots must finish after the selector receives EOF.
ipc "$entry" fixture capture shot region none >/dev/null
wait_value "$entry" fixture state idle
file=$(ipc "$entry" fixture result)
[[ -s $file ]] || fail 'Region screenshot did not save.'
touch "$scratch/cancel-selection"
ipc "$entry" fixture capture shot region none >/dev/null
wait_value "$entry" fixture state idle
rm "$scratch/cancel-selection"
touch "$scratch/fail-shot"
ipc "$entry" fixture capture shot monitor none >/dev/null
wait_value "$entry" fixture state error
rm "$scratch/fail-shot"
# A disconnected monitor fails before an encoder can start.
touch "$scratch/disconnected"
ipc "$entry" fixture capture shot monitor none >/dev/null
wait_value "$entry" fixture state error
rm "$scratch/disconnected"
# Reloading the bar finalizes its worker without replacing the worker process.
ipc "$entry" fixture capture record monitor none >/dev/null
wait_value "$entry" fixture state recording
printf '\n' >> "$scratch/config/check.qml"
wait_value "$entry" fixture ready ready
for ((attempt=0;attempt<120;attempt++)); do
  if [[ -f $scratch/events ]] && rg -q finalized "$scratch/events"; then break; fi
  sleep 0.1
done
rg -q finalized "$scratch/events" || fail 'Bar reload did not finalize recording.'
# Wait until worker cleanup is published before starting a second recording.
worker=$scratch/config/recorder.qml
for ((attempt=0;attempt<80;attempt++)); do
  worker_state=$(ipc "$worker" recorder status || true)
  if [[ $(jq -r '.state // ""' <<< "$worker_state" 2>/dev/null || true) == idle ]]; then break; fi
  sleep 0.1
done
wait_value "$entry" fixture state idle
: > "$scratch/events"
# Audio cleanup and Bluetooth profile/policy restoration after client SIGKILL.
touch "$scratch/bluetooth"
ipc "$entry" fixture capture record region both >/dev/null
wait_value "$entry" fixture state recording
kill -KILL "$bar"
wait "$bar" 2>/dev/null || true
for ((attempt=0;attempt<150;attempt++)); do
  if [[ -f $scratch/events ]] && rg -q finalized "$scratch/events"; then break; fi
  sleep 0.1
done
rg -q finalized "$scratch/events" || fail 'Heartbeat loss did not finalize recording.'
for ((attempt=0;attempt<80;attempt++)); do
  [[ $(cat "$scratch/profile") != a2dp-sink ]] || [[ $(rg -c '^unload-module 42$' "$scratch/audio-events") != 3 ]] || break
  sleep 0.1
done
[[ $(cat "$scratch/profile") == a2dp-sink ]] || fail 'Bluetooth profile was not restored.'
[[ $(rg -c '^unload-module 42$' "$scratch/audio-events") == 3 ]] || fail 'Audio modules leaked.'
rg -q '^settings bluetooth.autoswitch-to-headset-profile true$' "$scratch/policy-events" || fail 'Bluetooth policy was not restored.'
if rg -n 'TypeError|ReferenceError|Binding loop|Failed to load configuration' "$scratch/backend.log"; then fail 'Backend QML error.'; fi
# Exercise profile readback, charge authentication cancellation and confirmation.
cat > "$scratch/bin/busctl" <<'MOCK'
#!/usr/bin/env bash
if [[ $* == *get-property* ]]; then
  value=balanced
  [[ ! -f $ASTRAL_FIXTURE/native-profile ]] || value=$(cat "$ASTRAL_FIXTURE/native-profile")
  printf 's "%s"\n' "$value"
else
  pid=0
  [[ ! -f $ASTRAL_FIXTURE/inhibitor-pid ]] || pid=$(cat "$ASTRAL_FIXTURE/inhibitor-pid")
  if [[ $pid != 0 ]] && kill -0 "$pid" 2>/dev/null; then
    printf '{"data":[[["idle","astral-caffeine","keep active","block",1000,%s]]]}\n' "$pid"
  else printf '{"data":[[]]}\n'; fi
fi
MOCK
cat > "$scratch/bin/charge-helper" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == status ]] || exit 1
printf 'BAT0\n100\n\n\n'
MOCK
cat > "$scratch/bin/stat" <<'MOCK'
#!/usr/bin/env bash
if [[ $* == *charge-helper* ]]; then printf '0:755:regular file\n'; else exec /usr/bin/stat "$@"; fi
MOCK
cat > "$scratch/bin/pkexec" <<'MOCK'
#!/usr/bin/env bash
printf 'Authentication cancelled\n' >&2
exit 126
MOCK
cat > "$scratch/bin/test-session" <<'MOCK'
#!/usr/bin/env bash
printf 'session\n' >> "$ASTRAL_FIXTURE/session-events"
printf 'simulated provider failure\n' >&2
exit 1
MOCK
chmod 755 "$scratch/bin/"*
sed -i "s|/usr/local/libexec/astral-charge-limit|$scratch/bin/charge-helper|" "$scratch/config/astral-bar/data/PowerService.qml"
jq '.providers.lock=[] | .providers.suspend=[] | .providers.reboot=["test-session"]' "$scratch/config/settings.json" > "$scratch/settings"
cp "$scratch/settings" "$scratch/config/settings.json"
sed 's|../../config/quickshell/|./|g' tests/power/service.qml > "$scratch/config/power-test.qml"
timeout 25 "$qs_binary" -p "$scratch/config/power-test.qml" --no-color > "$scratch/power.log" 2>&1 || fail 'Power QML checks failed.'
rg -q POWER_PASS "$scratch/power.log" || fail 'Power fixture did not complete.'
[[ $(wc -l < "$scratch/session-events") == 1 ]] || fail 'Confirmation sent an extra session action.'
# Verify saved versus effective caffeine state without a real inhibitor.
cat > "$scratch/bin/systemd-inhibit" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == --what=idle ]] || exit 1
printf '%s\n' "$$" > "$ASTRAL_FIXTURE/inhibitor-pid"
exec sleep infinity
MOCK
chmod 755 "$scratch/bin/systemd-inhibit"
mkdir -p "$scratch/state/astral-shell"
printf 'on\n' > "$scratch/state/astral-shell/caffeine"
caffeine=$scratch/config/common/Caffeine.qml
"$qs_binary" -p "$caffeine" --no-duplicate > "$scratch/caffeine.log" 2>&1 &
caffeine_pid=$!
active=false
for ((attempt=0;attempt<100;attempt++)); do
  caffeine_state=$(ipc "$caffeine" caffeine status || true)
  active=$(jq -r '.active // false' <<< "$caffeine_state" 2>/dev/null || true)
  [[ $active != true ]] || break
  sleep 0.1
done
[[ $active == true ]] || fail 'Caffeine did not verify the owned inhibitor.'
printf 'off\n' > "$scratch/state/astral-shell/caffeine"
for ((attempt=0;attempt<80;attempt++)); do if ! kill -0 "$caffeine_pid" 2>/dev/null; then break; fi; sleep 0.1; done
if kill -0 "$caffeine_pid" 2>/dev/null; then fail 'Caffeine did not exit when disabled.'; fi
wait "$caffeine_pid"
if kill -0 "$(cat "$scratch/inhibitor-pid")" 2>/dev/null; then fail 'Caffeine inhibitor leaked.'; fi
printf 'QUICKSHELL_RUNTIME_PASS\n'
