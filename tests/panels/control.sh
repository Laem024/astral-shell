#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
scratch=$(astral_test_scratch panels-control)
qs_binary=$(command -v qs)
cleanup() { "$qs_binary" kill -p "$scratch/config/fixture.qml" >/dev/null 2>&1 || true; rm -rf -- "$scratch"; }
trap cleanup EXIT
trap 'cat "$scratch/"*.log >&2' ERR
mkdir -p "$scratch/config" "$scratch/run" "$scratch/bin"
chmod 700 "$scratch/run"
cp -a config/quickshell/. "$scratch/config/"
cp tests/panels/control.qml "$scratch/config/fixture.qml"
export ASTRAL_FIXTURE=$scratch XDG_RUNTIME_DIR=$scratch/run QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
printf '#!/usr/bin/env bash\ncat "$ASTRAL_FIXTURE/locked"\n' > "$scratch/bin/loginctl"
chmod 755 "$scratch/bin/loginctl"
export PATH=$scratch/bin:$PATH
for module in clipboard overview shortcuts; do
  cp tests/panels/control.qml "$scratch/config/fixture.qml"
  if [[ $module == overview ]]; then sed -i 's/function toggle(mode: string)/function toggle(mode: string, active: string)/' "$scratch/config/fixture.qml"; fi
  export ASTRAL_PANEL=$module
  printf 'no\n' > "$scratch/locked"
  printf 'inactive\n' > "$scratch/reply"
  jq --arg id "astral-$module" '.modules=[{id:$id,path:"fixture.qml",enabled:true,autostart:true}]' config/quickshell/settings.json > "$scratch/config/settings.json"
  request() { bash "$scratch/config/dispatch.sh" "$scratch/config/fixture.qml" "$module" "$@"; }
  request close > "$scratch/close.log" 2>&1
  request close-active > "$scratch/absent.log" 2>&1
  [[ ! -e $scratch/starts ]]
  request daemon > "$scratch/daemon.log" 2>&1 &
  first=$!
  request toggle > "$scratch/toggle.log" 2>&1 &
  second=$!
  wait "$first"; wait "$second"
  [[ $(wc -l < "$scratch/starts") == 1 ]]
  rg -q '^toggle ' "$scratch/calls"
  request close-active > "$scratch/inactive.log" 2>&1
  printf 'unknown\n' > "$scratch/reply"
  if request close-active > "$scratch/unknown.log" 2>&1; then exit 1; fi
  before=$(wc -l < "$scratch/calls")
  printf 'unknown\n' > "$scratch/locked"
  request toggle > "$scratch/blocked.log" 2>&1
  [[ $(wc -l < "$scratch/calls") == "$before" ]]
  if request invalid-action > "$scratch/invalid.log" 2>&1; then exit 1; fi
  "$qs_binary" kill -p "$scratch/config/fixture.qml" >/dev/null
  rm -- "$scratch/starts" "$scratch/calls"
done
printf 'PANELS_CONTROL_PASS (serialized startup, external entries, absent close, unknown replies, privacy)\n'
