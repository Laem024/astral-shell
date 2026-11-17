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
}
