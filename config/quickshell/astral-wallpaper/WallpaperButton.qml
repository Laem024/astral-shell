import QtQuick
import QtQuick.Controls

Button {
  required property var tokens
  id: control
  implicitHeight: 36
  leftPadding: 14; rightPadding: 14
  opacity: enabled ? 1 : 0.45
  background: Rectangle {
    radius: 9
    color: control.highlighted ? control.tokens.cyan : control.hovered ? Qt.alpha(control.tokens.cyan, 0.12) : control.tokens.background
    border.color: control.activeFocus ? control.tokens.cyan : control.tokens.border
  }
  contentItem: Text {
    text: control.text; font: control.font
    color: control.highlighted ? control.tokens.background : control.tokens.text
    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }
}
