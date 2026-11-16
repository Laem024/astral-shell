#!/usr/bin/env bash
# Instantiate the production views on ordinary offscreen surfaces, then all previews.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
scratch=$(astral_test_scratch panels-startup)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/config" "$scratch/run" "$scratch/bin" "$scratch/state" "$scratch/cache"
chmod 700 "$scratch/run"
cp -a config/quickshell/. "$scratch/config/"
cp tests/quickshell/Headless*.qml "$scratch/config/"
printf 'HeadlessPanel 1.0 HeadlessPanel.qml\nHeadlessAnchors 1.0 HeadlessAnchors.qml\nHeadlessMargins 1.0 HeadlessMargins.qml\n' > "$scratch/config/qmldir"
for module in clipboard overview shortcuts; do
  while IFS= read -r -d '' file; do
    if rg -q 'PanelWindow \{' "$file"; then
      sed -i -e 's/PanelWindow {/Headless.HeadlessPanel {/g' -e '/WlrLayershell\./d' "$file"
      sed -i '/^import QtQuick$/a import "root:/" as Headless' "$file"
    fi
  done < <(find "$scratch/config/astral-$module" -name '*.qml' -print0)
done
for tool in loginctl hyprctl wl-paste; do printf '#!/usr/bin/env bash\nexit 1\n' > "$scratch/bin/$tool"; done
chmod 755 "$scratch/bin/"*
export XDG_RUNTIME_DIR=$scratch/run XDG_STATE_HOME=$scratch/state XDG_CACHE_HOME=$scratch/cache PATH=$scratch/bin:$PATH
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
for module in clipboard overview shortcuts; do
  for kind in Root Preview; do
    printf 'import QtQuick\nimport "astral-%s" as Module\nModule.%s%s { Timer { interval: 600; running: true; onTriggered: Qt.quit() } }\n' "$module" "${module^}" "$kind" > "$scratch/config/check.qml"
    timeout 10 qs -p "$scratch/config/check.qml" --no-color > "$scratch/log" 2>&1 || { cat "$scratch/log"; exit 1; }
    if rg 'TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign|is not a type|Cannot assign' "$scratch/log"; then cat "$scratch/log"; exit 1; fi
  done
done
# Exercise delayed paste on the production panel with a simulated service.
printf no > "$scratch/locked"
printf '#!/usr/bin/env bash\ncat "$ASTRAL_FIXTURE/locked"\n' > "$scratch/bin/loginctl"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$ASTRAL_FIXTURE/pasted"\n' > "$scratch/bin/hyprctl"
export ASTRAL_FIXTURE=$scratch
sed 's|../../config/quickshell/|./|g' tests/clipboard/paste.qml > "$scratch/config/check.qml"
timeout 10 qs -p "$scratch/config/check.qml" --no-color > "$scratch/log" 2>&1 || { cat "$scratch/log"; exit 1; }
rg -q CLIPBOARD_PASTE_PASS "$scratch/log"
printf 'PANELS_STARTUP_PASS\n'
