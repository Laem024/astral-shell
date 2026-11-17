import "../common" as Common
import QtQuick

Rectangle {
  id: root
  required property var tokens
  property string label: ""
  property bool compact: false
  readonly property int horizontalPadding: root.compact ? 6 : 7
  readonly property int verticalPadding: root.compact ? 2 : 3
  implicitWidth: Math.max(root.compact ? 20 : 24, keyText.implicitWidth + root.horizontalPadding * 2)
  implicitHeight: keyText.implicitHeight + root.verticalPadding * 2
  radius: 6
  color: root.tokens.raised
  border.width: 1
  border.color: root.tokens.border

  // A hairline at the bottom gives the cap a subtle key-like depth.
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 2
    height: 1
    radius: 1
    color: Qt.alpha(root.tokens.text, 0.1)
  }

  Text {
    id: keyText
    anchors.centerIn: parent
    text: root.label
    color: root.tokens.text
    font {
      family: root.tokens.mono
      pixelSize: root.compact ? 10 : 11
      weight: Font.DemiBold
    }
  }
}
