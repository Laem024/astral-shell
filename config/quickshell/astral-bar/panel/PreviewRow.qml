import QtQuick
import QtQuick.Layouts
import "../../common" as Design

ColumnLayout {
  id: root
  required property Design.Theme tokens
  property string label: ""
  property string detail: ""
  property real level: -1
  Layout.fillWidth: true
  Layout.minimumWidth: 0
  spacing: 7
  Item {
    Layout.fillWidth: true
    implicitHeight: Math.max(caption.implicitHeight, value.implicitHeight)
    Text {
      id: caption
      width: parent.width * 0.48
      text: root.label
      color: root.tokens.text
      font { family: root.tokens.font; pixelSize: 13 }
      wrapMode: Text.Wrap
    }
    Text {
      id: value
      anchors.right: parent.right
      width: parent.width * 0.48
      text: root.detail
      color: root.tokens.muted
      font { family: root.tokens.mono; pixelSize: 10 }
      wrapMode: Text.Wrap
      horizontalAlignment: Text.AlignRight
    }
  }
  Rectangle {
    visible: root.level >= 0
    Layout.fillWidth: true
    implicitHeight: 4
    radius: 2
    color: Qt.alpha(root.tokens.muted, 0.16)
    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.level))
      height: parent.height
      radius: 2
      color: root.tokens.cyan
    }
  }
}
