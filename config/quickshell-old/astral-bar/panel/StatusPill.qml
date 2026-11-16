import QtQuick
import "../design" as Design

// Compact mono badge used for live state and profile types.
Rectangle {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  property string text: ""
  implicitWidth: label.implicitWidth + 16
  implicitHeight: 20
  radius: 10
  color: Qt.alpha(root.accent, 0.08)
  border.color: Qt.alpha(root.accent, 0.22)
  Accessible.ignored: true

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    textFormat: Text.PlainText
    color: root.accent
    font { family: root.tokens.mono; pixelSize: 8; letterSpacing: 0.7 }
  }
}
