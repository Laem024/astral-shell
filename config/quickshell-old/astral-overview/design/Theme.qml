import QtQuick

QtObject {
  required property var settings
  readonly property var palette: settings.value.colors[settings.value.mode === "light" ? "light" : "dark"]
  readonly property color background: palette.background
  readonly property color surface: palette.surface
  readonly property color text: palette.text
  readonly property color muted: palette.muted
  readonly property color cyan: palette.cyan
  readonly property color lavender: palette.lavender
  readonly property color gold: palette.gold
  readonly property color alert: palette.alert
  readonly property color border: Qt.alpha(muted, 0.18)
  readonly property string font: "sans-serif"
  readonly property string mono: "JetBrainsMono Nerd Font"
  readonly property real scale: settings.value.scale
  readonly property int unit: 4
  readonly property int gap: 8
  readonly property int padding: 12
  readonly property int inset: 16
  readonly property int section: 24
  readonly property int textSize: 12
  readonly property int labelSize: 14
  readonly property int iconSize: 20
  readonly property int hoverDuration: settings.value.animations ? 140 : 0
  readonly property int entryDuration: settings.value.animations ? 220 : 0
}
