import QtQuick
import "../../common" as Design

// Shared visual feedback; the owning control keeps its input and geometry.
Rectangle {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  property bool hovered: false
  property bool selected: false
  property bool focused: false
  property bool tinted: false
  radius: 12
  color: Qt.alpha(accent, selected ? 0.14 : hovered ? 0.09 : tinted ? 0.06 : 0)
  border.color: focused ? tokens.gold
    : Qt.alpha(accent, selected ? 0.35 : hovered ? 0.22 : tinted ? 0.12 : 0)
  Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
  Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
}
