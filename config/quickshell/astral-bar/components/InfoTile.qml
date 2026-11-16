import QtQuick
import QtQuick.Layouts
import "../../common" as Design

Item {
  id: root
  required property Design.Theme tokens
  property bool vertical: false
  property bool compact: false
  property string glyph: ""
  property int glyphSize: tokens.iconSize
  property string label: ""
  property string detail: label
  property color accent: tokens.cyan
  readonly property bool hovered: hover.hovered
  property color ink: hovered ? tokens.lavender : accent
  Behavior on ink { ColorAnimation { duration: root.tokens.hoverDuration } }
  property real level: -1
  property int labelLimit: 140
  signal activated()
  implicitWidth: vertical ? 52 : content.implicitWidth + tokens.inset
  implicitHeight: vertical ? (compact ? 38 : 50) : 36
  Accessible.name: detail
  Accessible.role: Accessible.Button
  GridLayout {
    id: content
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 2
    rowSpacing: 1
    columnSpacing: root.tokens.gap
    Text {
      Layout.alignment: Qt.AlignCenter
      text: root.glyph
      color: root.ink
      font.family: root.tokens.mono
      font.pixelSize: root.glyphSize
    }
    Text {
      visible: !root.compact
      Layout.alignment: Qt.AlignCenter
      Layout.maximumWidth: root.vertical ? 50 : root.labelLimit
      text: root.label
      elide: Text.ElideRight
      color: root.hovered ? root.tokens.cyan : root.tokens.text
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
      font.family: root.tokens.font
      font.pixelSize: root.vertical ? 12 : root.tokens.labelSize
    }
  }
  Meter {
    visible: root.level >= 0
    tokens: root.tokens
    value: root.level
    accent: root.accent
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 1
    anchors.horizontalCenter: parent.horizontalCenter
  }
  HoverHandler { id: hover }
  TapHandler { onTapped: root.activated() }
}
