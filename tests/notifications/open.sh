#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
runtime=$(astral_test_scratch n-open)
trap 'rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
sed 's|../../config/quickshell/|./|g' tests/notifications/open.qml > "$runtime/config/open.qml"
mkdir -p "$runtime/bin" "$runtime/run" "$runtime/home" "$runtime/cache" "$runtime/state" "$runtime/data"
chmod 700 "$runtime/run"
export HOME=$runtime/home XDG_RUNTIME_DIR=$runtime/run XDG_CONFIG_HOME=$runtime/config
export XDG_CACHE_HOME=$runtime/cache XDG_STATE_HOME=$runtime/state XDG_DATA_HOME=$runtime/data
export ASTRAL_OPEN_TEST=$runtime PATH="$runtime/bin:$PATH" QT_QPA_PLATFORM=offscreen
cat > "$runtime/bin/systemd-run" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
# Distinct files also prove simultaneous operations own independent launchers.
jq -n --args '$ARGS.positional' -- "$@" > "$ASTRAL_OPEN_TEST/args-$$.json"
sleep 0.1
[[ $* != *missing-manager* && $* != *'/failure/image.png'* ]]
MOCK
chmod +x "$runtime/bin/systemd-run"
timeout 15 qs -p "$runtime/config/open.qml" > "$runtime/log" 2>&1 || { cat "$runtime/log"; exit 1; }
rg -q NOTIFICATION_OPEN_PASS "$runtime/log"
! rg -q 'OPEN_FAIL|TypeError|ReferenceError' "$runtime/log"
jq -s -e --arg cache "$XDG_CACHE_HOME" --arg config "$XDG_CONFIG_HOME" --arg data "$XDG_DATA_HOME" --arg state "$XDG_STATE_HOME" '
  length == 5 and all(.[];
    index("--service-type=exec") != null and index("--property=ExitType=cgroup") != null and index("--expand-environment=no") != null
    and index("--setenv=XDG_CACHE_HOME=" + $cache) != null and index("--setenv=XDG_CONFIG_HOME=" + $config) != null
    and index("--setenv=XDG_DATA_HOME=" + $data) != null and index("--setenv=XDG_STATE_HOME=" + $state) != null)
  and any(.[]; .[-3:] == ["fake-video", "--flag", "/a dir/$HOME;`echo no` #?.mp4"])
  and any(.[]; .[-3:] == ["gio", "open", "/other/$(touch NEVER).png"])
  and any(.[]; index("--working-directory=/folder with spaces") != null and .[-2:] == ["fake-terminal", "$literal"])
' "$runtime"/args-*.json >/dev/null
printf 'NOTIFICATION_OPEN_PASS (literal arguments, XDG, concurrent launches, failure, terminal fallback)\n'
