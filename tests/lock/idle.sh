#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch idle-flow)
trap 'rm -rf -- "$runtime"' EXIT
cp -a config/quickshell "$runtime/config"
cp tests/lock/idle.qml "$runtime/config/idle-check.qml"
cp tests/lock/TestIdleMonitor.qml "$runtime/config/astral-lock/"
printf 'TestIdleMonitor 1.0 TestIdleMonitor.qml\n' >> "$runtime/config/astral-lock/qmldir"
sed -i 's/IdleMonitor {/TestIdleMonitor {/' "$runtime/config/astral-lock/IdleService.qml"
sed -i '/id: root/a\  property alias testInhibitor: inhibitor' "$runtime/config/astral-lock/SleepGuard.qml"
mkdir -p "$runtime/bin" "$runtime/run"
chmod 700 "$runtime/run"
cat > "$runtime/bin/busctl" <<'MOCK'
#!/usr/bin/env bash
echo '{"data":["/org/freedesktop/login1/session/test"]}'
MOCK
cat > "$runtime/bin/qs" <<'MOCK'
#!/usr/bin/env bash
echo secure
MOCK
cat > "$runtime/bin/dbus-monitor" <<'MOCK'
#!/usr/bin/env bash
exec sleep 20
MOCK
cat > "$runtime/bin/systemd-inhibit" <<'MOCK'
#!/usr/bin/env bash
exec tee
MOCK
cat > "$runtime/bin/astral-lock" <<'MOCK'
#!/usr/bin/env bash
echo "unexpected lock request" >> "$ASTRAL_IDLE_TEST/actions"
exit 1
MOCK
chmod 755 "$runtime/bin/"*
qs_binary=$(command -v qs)
export ASTRAL_IDLE_TEST=$runtime XDG_RUNTIME_DIR=$runtime/run XDG_CACHE_HOME=$runtime/cache XDG_STATE_HOME=$runtime/state
export PATH=$runtime/bin:$PATH QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
output=$(timeout 15 "$qs_binary" -p "$runtime/config/idle-check.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *IDLE_PASS* && $output != *IDLE_FAIL* ]]
! rg -q 'ERROR|TypeError|ReferenceError|Binding loop' <<< "$output"
[[ ! -f $runtime/actions ]]
