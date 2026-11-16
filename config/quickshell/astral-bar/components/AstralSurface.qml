pragma ComponentBehavior: Bound
import QtQuick
import "../../common" as Design

Item {
  id: root
  objectName: "astralSurface"
  required property Design.Theme tokens
  property bool vertical: false
  property string position: "top"
  Rectangle {
    anchors.fill: parent
    anchors.margins: 3
    radius: 9
    color: root.tokens.background
    border.color: root.tokens.border
  }
  Repeater {
    model: 2
    Rectangle {
      required property int index
      x: root.vertical ? (root.width - width) / 2 : (index === 0 ? 8 : root.width - 10)
      y: root.vertical ? (index === 0 ? 8 : root.height - 10) : (root.height - height) / 2
      width: 2; height: 2; radius: 1
      color: root.tokens.muted
      opacity: 0.4
    }
  }
}
