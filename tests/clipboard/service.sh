#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
scratch=$(astral_test_scratch clipboard-service)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/config" "$scratch/bin" "$scratch/run" "$scratch/state" "$scratch/cache"
chmod 700 "$scratch/run"
cp -a config/quickshell/. "$scratch/config/"
sed 's|../../config/quickshell/|./|g' tests/clipboard/service.qml > "$scratch/config/check.qml"
export ASTRAL_FIXTURE=$scratch XDG_RUNTIME_DIR=$scratch/run XDG_STATE_HOME=$scratch/state XDG_CACHE_HOME=$scratch/cache
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
export PATH=$scratch/bin:$PATH
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
printf 'no' > "$scratch/locked"
cat > "$scratch/bin/loginctl" <<'MOCK'
#!/usr/bin/env bash
cat "$ASTRAL_FIXTURE/locked"
MOCK
cat > "$scratch/bin/wl-paste" <<'MOCK'
#!/usr/bin/env bash
case $1 in
  --watch)
    printf 'data\n'
    # A restart reports the retained selection once, just like wl-paste.
    exec sleep infinity ;;
  --list-types) cat "$ASTRAL_FIXTURE/types" ;;
  --no-newline)
    [[ ! -f $ASTRAL_FIXTURE/delay ]] || sleep 0.8
    if [[ -f $ASTRAL_FIXTURE/copied ]]; then cat "$ASTRAL_FIXTURE/copied";
    elif [[ $(cat "$ASTRAL_FIXTURE/kind") == image ]]; then printf '\211PNG\000\377\200\n';
    else cat "$ASTRAL_FIXTURE/input"; fi ;;
  *) exit 1 ;;
esac
MOCK
cat > "$scratch/bin/systemd-run" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$ASTRAL_FIXTURE/copy-args"
for arg in "$@"; do
  if [[ $arg == --property=StandardInput=file:* ]]; then
    path=${arg#--property=StandardInput=file:}
    path=${path//%%/%}
    cat "$path" > "$ASTRAL_FIXTURE/copied"
  fi
done
MOCK
cat > "$scratch/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ASTRAL_FIXTURE/stops"
MOCK
chmod 755 "$scratch/bin/"*
timeout 30 qs -p "$scratch/config/check.qml" --no-color > "$scratch/log" 2>&1 || { cat "$scratch/log"; exit 1; }
cat "$scratch/log"
rg -q CLIPBOARD_SERVICE_PASS "$scratch/log"
if rg -q 'TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign' "$scratch/log"; then exit 1; fi
# A separate restart must retain corrupt bytes until explicit clear.
printf '{broken history' > "$scratch/state/astral-shell/astral-clipboard/history.json"
printf no > "$scratch/locked"
export ASTRAL_CORRUPT=1
timeout 20 qs -p "$scratch/config/check.qml" --no-color > "$scratch/corrupt.log" 2>&1 || { cat "$scratch/corrupt.log"; exit 1; }
rg -q CLIPBOARD_CORRUPT_PASS "$scratch/corrupt.log"
[[ $(stat -c %a "$scratch/state/astral-shell/astral-clipboard/history.json") == 600 ]]
printf 'CLIPBOARD_SERVICE_PASS (binary data, copy confirmation, queue, MIME, limits, privacy, corrupt recovery)\n'
