import QtQuick
import QtQuick.Layouts

RowLayout {
  id: hint
  required property var tokens
  required property string keys
  required property string label
  property bool accent: false
  spacing: 6
  Rectangle {
    implicitWidth: keyText.implicitWidth + 12
    implicitHeight: 22
    radius: 6
    color: hint.accent ? Qt.alpha(hint.tokens.cyan, 0.12) : hint.tokens.raised
    border.width: 1
    border.color: hint.accent ? Qt.alpha(hint.tokens.cyan, 0.4) : hint.tokens.border
    Text {
      id: keyText
      anchors.centerIn: parent
      text: hint.keys
      color: hint.accent ? hint.tokens.cyan : hint.tokens.text
      font.family: hint.tokens.mono; font.pixelSize: 10; font.weight: Font.DemiBold
    }
  }
  Text {
    text: hint.label
    color: hint.accent ? hint.tokens.cyan : hint.tokens.muted
    font.family: hint.tokens.font; font.pixelSize: 11
  }
}
