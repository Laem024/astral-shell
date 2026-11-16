pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  required property var tokens
  property string key: ""
  property string label: ""
  spacing: 6

  Rectangle {
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: keyText.implicitWidth + 14
    implicitHeight: 20
    radius: 6
    color: Qt.alpha(root.tokens.cyan, 0.10)
    border.width: 1
    border.color: Qt.alpha(root.tokens.cyan, 0.22)
    Text {
      id: keyText
      anchors.centerIn: parent
      text: root.key
      color: root.tokens.cyan
      font.family: root.tokens.mono
      font.pixelSize: 8
      font.letterSpacing: 1.1
    }
  }

  Text {
    Layout.alignment: Qt.AlignVCenter
    text: root.label
    color: root.tokens.muted
    font.family: root.tokens.font
    font.pixelSize: 10
  }
}
