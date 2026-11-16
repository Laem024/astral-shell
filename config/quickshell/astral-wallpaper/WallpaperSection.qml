import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Grouped settings surface: a quiet card with a title and free-form content.
Rectangle {
  id: root
  objectName: "wallpaperSection"
  required property var tokens
  property string title: ""
  property string description: ""
  default property alias content: body.data
  Layout.fillWidth: true
  implicitHeight: column.implicitHeight + 32
  radius: 16
  color: Qt.alpha(tokens.background, 0.6)
  border.color: tokens.border
  ColumnLayout {
    id: column
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
    spacing: 4
    Label {
      text: root.title.toUpperCase()
      visible: text.length > 0
      font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
      color: root.tokens.cyan
    }
    Label {
      Layout.fillWidth: true
      Layout.topMargin: 2
      Layout.bottomMargin: 8
      text: root.description
      visible: text.length > 0
      wrapMode: Text.Wrap
      font.pixelSize: 11
      color: root.tokens.muted
    }
    ColumnLayout {
      id: body
      Layout.fillWidth: true
      spacing: 10
    }
  }
}
