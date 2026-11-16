#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
command -v qs >/dev/null || { printf 'SKIP: startup smoke check requires qs.\n'; exit 0; }
source tests/xdg-scratch.sh
scratch=$(astral_test_scratch startup-test)
trap 'rm -rf -- "$scratch"' EXIT
cp -a config/quickshell "$scratch/config"
jq -e '.modules[] | select(.id == "astral-bar") | .path == "bar.qml"' "$scratch/config/settings.json" >/dev/null
cp tests/quickshell/Headless*.qml "$scratch/config/"
printf 'HeadlessPanel 1.0 HeadlessPanel.qml\nHeadlessAnchors 1.0 HeadlessAnchors.qml\nHeadlessMargins 1.0 HeadlessMargins.qml\n' > "$scratch/config/qmldir"
# Rewrite only this copy's native layer surfaces. Every real bar component,
# shared import, visual slot and binding still has to compile and instantiate.
while IFS= read -r -d '' file; do
  if rg -q 'PanelWindow \{' "$file"; then
    sed -i -e 's/PanelWindow {/Headless.HeadlessPanel {/g' -e '/WlrLayershell\./d' "$file"
    sed -i '/^import QtQuick$/a import "root:/" as Headless' "$file"
  fi
done < <(find "$scratch/config/astral-bar" -name '*.qml' -print0)
cat > "$scratch/config/bar.qml" <<'QML'
import QtQuick
import "astral-bar" as Bar

Bar.BarRoot {
  Timer { interval: 1000; running: true; onTriggered: Qt.quit() }
}
QML
mkdir -p "$scratch/run" "$scratch/home" "$scratch/cache" "$scratch/state" "$scratch/data" "$scratch/bin"
chmod 700 "$scratch/run"
for tool in curl nmcli hyprctl loginctl; do
  printf '#!/usr/bin/env bash\nexit 1\n' > "$scratch/bin/$tool"
  chmod 755 "$scratch/bin/$tool"
done
export HOME=$scratch/home XDG_RUNTIME_DIR=$scratch/run XDG_CACHE_HOME=$scratch/cache XDG_STATE_HOME=$scratch/state XDG_DATA_HOME=$scratch/data XDG_CONFIG_HOME=$scratch
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
export PATH=$scratch/bin:$PATH
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
if ! timeout 10 qs -p "$scratch/config/bar.qml" --no-color > "$scratch/log" 2>&1; then cat "$scratch/log"; exit 1; fi
if ! rg -q 'Configuration Loaded' "$scratch/log" || rg -q 'Failed to load configuration|TypeError|ReferenceError|Binding loop|is not a type|Component is not ready' "$scratch/log"; then cat "$scratch/log"; exit 1; fi
printf 'QUICKSHELL_STARTUP_PASS\n'
