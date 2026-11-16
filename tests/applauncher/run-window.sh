#!/usr/bin/env bash
# Exercise the real launcher visual tree using isolated ordinary test windows.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
if [[ ${1:-} != --isolated ]]; then astral_test_dbus -- bash "$0" --isolated; exit $?; fi
runtime=$(astral_test_scratch launcher-window)
trap 'rm -rf -- "$runtime"' EXIT
cp -a config/quickshell "$runtime/config"
cp tests/quickshell/Headless*.qml "$runtime/config/"
printf 'HeadlessPanel 1.0 HeadlessPanel.qml\nHeadlessAnchors 1.0 HeadlessAnchors.qml\nHeadlessMargins 1.0 HeadlessMargins.qml\n' > "$runtime/config/qmldir"
sed -i -e 's/PanelWindow {/Headless.HeadlessPanel {/g' -e '/WlrLayershell\./d' "$runtime/config/astral-launcher/AppLauncher.qml"
sed -i '/^import QtQuick$/a import "root:/" as Headless' "$runtime/config/astral-launcher/AppLauncher.qml"
sed 's|../../config/quickshell/|./|g' tests/applauncher/window.qml > "$runtime/config/window.qml"
mkdir -p "$runtime/run" "$runtime/home" "$runtime/bin"
chmod 700 "$runtime/run"
printf '#!/usr/bin/env bash\nprintf "no\\n"\n' > "$runtime/bin/loginctl"
chmod 755 "$runtime/bin/loginctl"
export PATH=$runtime/bin:$PATH XDG_RUNTIME_DIR=$runtime/run HOME=$runtime/home
export XDG_STATE_HOME=$runtime/state XDG_CACHE_HOME=$runtime/cache XDG_CONFIG_HOME=$runtime/config XDG_DATA_HOME=$runtime/data
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
output=$(timeout 8 qs -p "$runtime/config/window.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *LAUNCHER_WINDOW_PASS* && $output != *LAUNCHER_WINDOW_FAIL* ]]
! [[ $output == *'TypeError'* || $output == *'ReferenceError'* || $output == *'Binding loop'* || $output == *'Failed to load configuration'* ]]
