pragma ComponentBehavior: Bound
import QtQuick
import "../../common" as Design

Row {
  id: root
  required property Design.Theme tokens
  property real value: 0
  property color accent: tokens.cyan
  spacing: 2
  Repeater {
    model: 8
    Rectangle {
      required property int index
      width: 3; height: 3
      radius: 1
      color: index < Math.round(root.value * 8) ? root.accent : Qt.alpha(root.tokens.muted, 0.2)
    }
  }
}
