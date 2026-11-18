import QtQuick
import QtQuick.Layouts
import "../../common" as Design

// Shared section surface: one radius, one inner margin and one optional header.
Rectangle {
  id: root
  required property Design.Theme tokens
  property string title: ""
  property color accent: tokens.cyan
  property real contentSpacing: 12
  default property alias contents: body.data
  implicitHeight: body.implicitHeight + tokens.inset * 2
  Layout.fillWidth: true
  Layout.minimumHeight: implicitHeight
  Layout.fillHeight: false
  radius: tokens.cardRadius
  gradient: Gradient {
    GradientStop { position: 0; color: Qt.tint(root.tokens.background, Qt.alpha(root.accent, 0.045)) }
    GradientStop { position: 1; color: root.tokens.background }
  }
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
      color: root.accent
      font { family: root.tokens.mono; pixelSize: 9; weight: Font.Medium; letterSpacing: 1.3 }
      wrapMode: Text.Wrap
    }
  }
}
