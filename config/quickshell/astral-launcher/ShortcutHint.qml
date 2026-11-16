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
    implicitWidth: keyText.implicitWidth + 10
    implicitHeight: 22
    radius: 5
    color: hint.tokens.background
    border.color: hint.tokens.border
    Text {
      id: keyText
      anchors.centerIn: parent
      text: hint.keys
      color: hint.accent ? hint.tokens.cyan : hint.tokens.muted
      font.family: hint.tokens.mono; font.pixelSize: 10
    }
  }
  Text { text: hint.label; color: hint.accent ? hint.tokens.cyan : hint.tokens.muted; font.family: hint.tokens.font; font.pixelSize: 10 }
}
