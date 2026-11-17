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
    radius: Math.min(root.tokens.panelRadius, Math.min(width, height) / 2)
    gradient: Gradient {
      orientation: root.vertical ? Gradient.Horizontal : Gradient.Vertical
      GradientStop { position: 0; color: Qt.tint(root.tokens.surface, Qt.alpha(root.tokens.text, 0.025)) }
      GradientStop { position: 1; color: root.tokens.surface }
    }
    border.color: root.tokens.border
    border.width: 1
  }
  Repeater {
    model: 2
    Rectangle {
      required property int index
      objectName: "barEndDetail-" + index
      x: root.vertical ? (root.width - width) / 2 : (index === 0 ? 6 : root.width - width - 6)
      y: root.vertical ? (index === 0 ? 6 : root.height - height - 6) : (root.height - height) / 2
      width: root.vertical ? 12 : 2
      height: root.vertical ? 2 : 12
      radius: 1
      color: Qt.alpha(root.tokens.cyan, 0.45)
    }
  }
}
