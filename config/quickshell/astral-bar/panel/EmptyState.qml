import QtQuick
import QtQuick.Layouts
import "../../common" as Design

// Shared quiet panel for empty or unavailable lists. It centres its mark,
// title and message and wraps text instead of growing past the card.
Rectangle {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  property string mark: ""
  property string title: ""
  property string message: ""
  Layout.fillWidth: true
  implicitHeight: body.implicitHeight + tokens.inset * 2
  radius: tokens.rowRadius
  color: tokens.sunken
  border.color: tokens.hairline

  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.tokens.inset }
    spacing: 8
    ConnectionMark {
      visible: root.mark !== ""
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: 40
      Layout.preferredHeight: 40
      tokens: root.tokens
      kind: root.mark
      accent: root.accent
      active: false
    }
    Text {
      Layout.fillWidth: true
      text: root.title
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      color: root.tokens.text
      font { family: root.tokens.font; pixelSize: 14; weight: Font.Medium }
    }
    Text {
      Layout.fillWidth: true
      text: root.message
      visible: text !== ""
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      color: root.tokens.muted
      font { family: root.tokens.font; pixelSize: 11 }
    }
  }
}
