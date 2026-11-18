import QtQuick
import QtQuick.Controls
import "../../common" as Design

Switch {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  implicitWidth: 44
  implicitHeight: 28
  padding: 0
  focusPolicy: Qt.StrongFocus
  indicator: Rectangle {
    x: 0
    y: (root.height - height) / 2
    implicitWidth: 44
    implicitHeight: 24
    radius: height / 2
    color: root.checked ? root.accent : Qt.alpha(root.tokens.muted, 0.24)
    border.width: root.activeFocus ? 2 : 0
    border.color: root.tokens.cyan
    Rectangle {
      x: root.checked ? parent.width - width - 3 : 3
      y: 3
      width: 18
      height: 18
      radius: 9
      color: root.checked ? root.tokens.background : root.tokens.text
      Behavior on x { NumberAnimation { duration: root.tokens.hoverDuration } }
    }
  }
}
