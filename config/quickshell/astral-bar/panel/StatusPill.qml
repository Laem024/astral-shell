import QtQuick
import "../../common" as Design

// Compact mono badge used for live state and profile types.
Rectangle {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  property string text: ""
  implicitWidth: label.implicitWidth + 16
  implicitHeight: 22
  radius: height / 2
  color: Qt.alpha(root.accent, 0.12)
  border.color: Qt.alpha(root.accent, 0.3)
  Accessible.ignored: true

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    textFormat: Text.PlainText
    color: root.accent
    font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 0.6 }
  }
}
