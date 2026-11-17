#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
scratch=$(astral_test_scratch central-panel)
trap 'rm -rf -- "$scratch"' EXIT
cp -a config/quickshell "$scratch/config"
cp tests/panels/central.qml "$scratch/config/central.qml"
mkdir -p "$scratch/"{home,run,state,cache,bin}
chmod 700 "$scratch/run"
# The visual check never connects or changes hardware, media or session state.
for tool in nmcli bluetoothctl curl hyprctl wpctl pactl pw-dump systemctl loginctl; do
  printf '#!/usr/bin/env bash\nexit 1\n' > "$scratch/bin/$tool"
  chmod 755 "$scratch/bin/$tool"
done
export PATH="$scratch/bin:$PATH"
export HOME="$scratch/home" XDG_RUNTIME_DIR="$scratch/run" XDG_STATE_HOME="$scratch/state" XDG_CACHE_HOME="$scratch/cache" XDG_CONFIG_HOME="$scratch/config"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=${QT_QUICK_BACKEND:-software} QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
output=$(timeout 20 qs --path "$scratch/config/central.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *CENTRAL_PANEL_PASS* && $output != *CENTRAL_PANEL_FAIL* ]]
# No PipeWire socket exists in the private runtime; UI errors still fail.
ui_output=$(printf '%s\n' "$output" | sed '/ERROR quickshell.service.pipewire.loop: Failed to connect pipewire context/d')
! [[ $ui_output == *'ERROR'* || $ui_output == *'TypeError'* || $ui_output == *'ReferenceError'* || $ui_output == *'Binding loop'* || $ui_output == *'Cannot assign'* ]]
