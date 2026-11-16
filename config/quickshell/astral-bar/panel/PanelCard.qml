import QtQuick
import QtQuick.Layouts
import "../../common" as Design

Rectangle {
  id: root
  required property Design.Theme tokens
  property string title: ""
  property real contentSpacing: 12
  default property alias contents: body.data
  implicitHeight: body.implicitHeight + 32
  Layout.fillWidth: true
  Layout.minimumHeight: implicitHeight
  Layout.fillHeight: false
  radius: 7
  color: tokens.background
  border.color: tokens.border
  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
    spacing: root.contentSpacing
    Text {
      Layout.fillWidth: true
      text: root.title
      textFormat: Text.PlainText
      visible: text !== ""
      color: root.tokens.cyan
      font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1 }
      wrapMode: Text.Wrap
    }
  }
}
