import QtQuick
import QtQuick.Controls

Button {
  required property var tokens
  id: control
  implicitHeight: 38
  leftPadding: 18; rightPadding: 18
  hoverEnabled: true
  font.family: tokens.font
  font.pixelSize: 13
  font.bold: highlighted
  opacity: enabled ? 1 : 0.45
  background: Rectangle {
    radius: height / 2
    color: control.highlighted ? control.tokens.cyan
      : control.hovered ? Qt.alpha(control.tokens.cyan, 0.14)
      : control.tokens.raised
    border.width: control.activeFocus ? 2 : 1
    border.color: control.activeFocus ? control.tokens.cyan
      : control.hovered ? Qt.alpha(control.tokens.cyan, 0.5)
      : control.tokens.border
    Behavior on color { ColorAnimation { duration: control.tokens.hoverDuration } }
    Behavior on border.color { ColorAnimation { duration: control.tokens.hoverDuration } }
  }
  contentItem: Text {
    text: control.text; font: control.font
    color: control.highlighted ? control.tokens.background : control.tokens.text
    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }
}
