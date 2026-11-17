#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
source tests/xdg-scratch.sh
runtime=$(astral_test_scratch media)
trap 'rm -rf -- "$runtime"' EXIT
cp -r config/quickshell "$runtime/config"
mkdir -p "$runtime/bin"; export PATH="$runtime/bin:$PATH"
mkdir "$runtime/run"
mkdir -p "$runtime/home" "$runtime/state"
# Isolate geometry from live PipeWire devices; no system settings are changed.
cat > "$runtime/config/astral-bar/data/SystemData.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
  readonly property string networkLabel: "WiFi"
  readonly property string networkState: "wifi"
  readonly property string networkDetail: "Layout fixture"
  readonly property real networkLevel: 0.8
  readonly property int volume: 65
  readonly property bool muted: false
  readonly property string audioDetail: "Layout fixture"
  readonly property int batteryPercent: 80
  readonly property bool externalPower: true
  readonly property bool discharging: false
  readonly property string batteryState: "Charging"
}
QML
sed 's|../../config/quickshell/|./|g' tests/media/layout.qml > "$runtime/config/media-layout-test.qml"
output=$(XDG_RUNTIME_DIR="$runtime/run" HOME="$runtime/home" XDG_STATE_HOME="$runtime/state" QT_QPA_PLATFORM=offscreen timeout 12 qs --path "$runtime/config/media-layout-test.qml" --no-color 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *MEDIA_LAYOUT_PASS* && $output != *MEDIA_LAYOUT_FAIL* ]]
! [[ $output == *'ERROR'* || $output == *'TypeError'* || $output == *'ReferenceError'* || $output == *'Binding loop'* ]]
