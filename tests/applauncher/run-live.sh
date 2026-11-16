#!/usr/bin/env bash
# Real user-service lifetime check. No packages or installed config are changed.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
if ! systemctl --user show-environment >/dev/null 2>&1; then
  printf 'SKIP: real application lifetime requires an accessible systemd user manager.\n'
  exit 0
fi
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch launcher-live)
cleanup() {
  touch "$runtime/release"
  qs kill -p "$runtime/config/live-launch.qml" >/dev/null 2>&1 || true
  # Let the bounded fixture finish before removing its private files.
  for ((attempt = 0; attempt < 30; attempt++)); do
    [[ ! -e $runtime/args || -e $runtime/survived ]] && break
    sleep 0.05
  done
  rm -rf -- "$runtime"
}
trap cleanup EXIT
mkdir -p "$runtime/config" "$runtime/working dir" "$runtime/run"
chmod 700 "$runtime/run"
# systemd-run uses the manager's private socket, independently of the D-Bus URL.
# Keep that socket reachable while qs logs and IPC remain in this test's runtime.
ln -s -- "$XDG_RUNTIME_DIR/systemd" "$runtime/run/systemd"
cp -a config/quickshell/common "$runtime/config/"
if [[ ${1:-} == --notifications ]]; then
  cp -a config/quickshell/. "$runtime/config/"
  cp tests/notifications/live-launch.qml "$runtime/config/live-launch.qml"
else
  cp tests/applauncher/live-launch.qml "$runtime/config/"
fi
cat > "$runtime/fixture" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
# Locate private output without depending on inherited test-only environment.
directory=${0%/*}
pwd > "$directory/cwd"
printf '%s\n' "$@" > "$directory/args"
(
  for ((attempt = 0; attempt < 200; attempt++)); do
    if [[ -e $directory/release ]]; then printf 'survived\n' > "$directory/survived"; exit 0; fi
    sleep 0.05
  done
) &
# Deliberately exit the main process before the descendant.
MOCK
chmod 755 "$runtime/fixture"
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
export ASTRAL_LIVE_DIR=$runtime XDG_RUNTIME_DIR=$runtime/run QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
qs -d -n -p "$runtime/config/live-launch.qml"
wait_file() {
  for ((attempt = 0; attempt < 80; attempt++)); do
    [[ ! -s $1 ]] || return 0
    sleep 0.05
  done
  qs log -p "$runtime/config/live-launch.qml" --no-color -t 80 >&2 || true
  return 1
}
wait_file "$runtime/accepted"
wait_file "$runtime/args"
[[ $(cat "$runtime/cwd") == "$runtime/working dir" ]]
cat > "$runtime/expected" <<'ARGS'
a b
$(touch INJECTED)
; touch INJECTED
$HOME
'quoted'
ARGS
cmp "$runtime/expected" "$runtime/args"
[[ ! -e $runtime/working\ dir/INJECTED ]]
printf '\n// Exercise a live QML reload.\n' >> "$runtime/config/live-launch.qml"
for ((attempt = 0; attempt < 80; attempt++)); do
  log=$(qs log -p "$runtime/config/live-launch.qml" --no-color -t 100 2>&1)
  [[ $(rg -c 'Configuration Loaded' <<< "$log") -lt 2 ]] || break
  sleep 0.05
done
[[ $(rg -c 'Configuration Loaded' <<< "$log") -ge 2 ]]
qs kill -p "$runtime/config/live-launch.qml"
touch "$runtime/release"
wait_file "$runtime/survived"
printf '%s_LIFETIME_PASS (literal user-service arguments, working directory, reload and shutdown survival)\n' "$([[ ${1:-} == --notifications ]] && printf NOTIFICATIONS || printf LAUNCHER)"
