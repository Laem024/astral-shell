import QtQuick
import QtQuick.Layouts
import "../../common" as Design

// Shared section surface: one radius, one inner margin and one optional header.
Rectangle {
  id: root
  required property Design.Theme tokens
  property string title: ""
  property real contentSpacing: 12
  default property alias contents: body.data
  implicitHeight: body.implicitHeight + tokens.inset * 2
  Layout.fillWidth: true
  Layout.minimumHeight: implicitHeight
  Layout.fillHeight: false
  radius: tokens.cardRadius
  color: tokens.raised
  border.color: tokens.border
  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.tokens.inset }
    spacing: root.contentSpacing
    Text {
      Layout.fillWidth: true
      text: root.title
      textFormat: Text.PlainText
      visible: text !== ""
      color: root.tokens.muted
      font { family: root.tokens.font; pixelSize: 11; weight: Font.Medium; letterSpacing: 0.6 }
      wrapMode: Text.Wrap
    }
  }
}
