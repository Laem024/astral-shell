import QtQuick
import QtQuick.Layouts
import "../../common" as Design

// Shared quiet panel for empty or unavailable lists.
Rectangle {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  property string mark: ""
  property string title: ""
  property string message: ""
  Layout.fillWidth: true
  implicitHeight: body.implicitHeight + 32
  radius: 10
  color: Qt.alpha(tokens.surface, 0.4)
  border.color: tokens.border

  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
    spacing: 6
    ConnectionMark {
      visible: root.mark !== ""
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: 34
      Layout.preferredHeight: 34
      Layout.topMargin: 2
      Layout.bottomMargin: 2
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
      font { family: root.tokens.font; pixelSize: 13; weight: Font.Medium }
    }
    Text {
      Layout.fillWidth: true
      text: root.message
      visible: text !== ""
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      color: root.tokens.muted
      font { family: root.tokens.font; pixelSize: 10 }
    }
  }
}
