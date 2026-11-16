import QtQuick
import QtQuick.Controls
import "../../common" as Design

Switch {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  implicitWidth: 46
  implicitHeight: 30
  padding: 0
  indicator: Rectangle {
    x: 0
    y: 3
    implicitWidth: 46
    implicitHeight: 24
    radius: 12
    color: root.checked ? root.accent : Qt.alpha(root.tokens.muted, 0.22)
    border.color: root.activeFocus ? root.tokens.text
      : root.checked ? "transparent" : root.tokens.border
    Rectangle {
      x: root.checked ? 25 : 3
      y: 3
      width: 18
      height: 18
      radius: 9
      color: root.checked ? root.tokens.background : root.tokens.muted
      Behavior on x { NumberAnimation { duration: root.tokens.hoverDuration } }
    }
  }
}
