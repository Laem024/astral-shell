import QtQuick
import QtQuick.Controls

TextField {
  id: root
  required property var tokens
  implicitHeight: 38
  leftPadding: 12; rightPadding: 12
  color: tokens.text
  placeholderTextColor: tokens.muted
  selectionColor: Qt.alpha(tokens.cyan, 0.3)
  selectedTextColor: tokens.text
  font.family: tokens.font
  font.pixelSize: 12
  selectByMouse: true
  opacity: enabled ? 1 : 0.45
  background: Rectangle {
    radius: root.tokens.rowRadius
    color: root.tokens.sunken
    border.color: root.activeFocus ? root.tokens.cyan : root.tokens.border
    border.width: root.activeFocus ? 2 : 1
  }
}
