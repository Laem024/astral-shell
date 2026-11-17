pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  required property var tokens
  property string key: ""
  property bool monitorIcon: false
  property string label: ""
  spacing: 8

  Rectangle {
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: Math.max(28, (root.monitorIcon ? monitorGlyph.implicitWidth : keyText.implicitWidth) + 16)
    implicitHeight: 26
    radius: height / 2
    color: root.tokens.raised
    border.width: 1
    border.color: root.tokens.border
    Text {
      id: keyText
      visible: !root.monitorIcon
      anchors.centerIn: parent
      text: root.key
      color: root.tokens.text
      font.family: root.tokens.mono
      font.pixelSize: 11
      font.letterSpacing: 0.5
    }
    MonitorGlyph {
      id: monitorGlyph
      anchors.centerIn: parent
      visible: root.monitorIcon
      ink: root.tokens.text
    }
  }

  Text {
    Layout.alignment: Qt.AlignVCenter
    text: root.label
    color: root.tokens.muted
    font.family: root.tokens.font
    font.pixelSize: 12
  }
}
