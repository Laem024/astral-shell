import QtQuick

QtObject {
  required property var settings
  readonly property bool light: settings.value.mode === "light"
  readonly property var palette: settings.value.colors[light ? "light" : "dark"]
  readonly property color background: palette.background
  readonly property color surface: palette.surface
  readonly property color text: palette.text
  readonly property color muted: palette.muted
  readonly property color cyan: palette.cyan
  readonly property color lavender: palette.lavender
  readonly property color gold: palette.gold
  readonly property color alert: palette.alert
  readonly property color raised: Qt.tint(surface, Qt.alpha(text, light ? 0.05 : 0.06))
  readonly property color sunken: Qt.tint(background, Qt.alpha(text, 0.03))
  readonly property color border: Qt.alpha(text, light ? 0.14 : 0.1)
  readonly property color hairline: Qt.alpha(text, 0.06)
  readonly property color scrim: Qt.alpha(background, 0.72)
  readonly property var accents: [cyan, lavender, gold]
  readonly property int panelRadius: 20
  readonly property int cardRadius: 14
  readonly property int rowRadius: 10
  readonly property int controlRadius: 999
  function accentAt(index) { return accents[((index % accents.length) + accents.length) % accents.length]; }
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
  readonly property int clockSize: 28
  readonly property int iconSize: 20
  readonly property int horizontalSize: 64
  readonly property int verticalSize: 76
  readonly property int hoverDuration: settings.value.animations ? 140 : 0
  readonly property int workspaceDuration: settings.value.animations ? 260 : 0
  readonly property int entryDuration: settings.value.animations ? 220 : 0
}
