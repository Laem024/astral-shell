import QtQuick
import QtQuick.Controls

// Large, quiet toggle for the settings cards.
Switch {
  id: control
  required property var tokens
  implicitWidth: 52; implicitHeight: 30
  padding: 0
  hoverEnabled: true
  opacity: enabled ? 1 : 0.45
  indicator: Rectangle {
    x: 0; y: 0
    implicitWidth: 52; implicitHeight: 30; radius: 15
    color: control.checked ? control.tokens.cyan : control.tokens.sunken
    border.width: control.activeFocus ? 2 : 1
    border.color: control.activeFocus || control.hovered ? control.tokens.cyan : control.tokens.border
    Behavior on color { ColorAnimation { duration: control.tokens.hoverDuration } }
    Rectangle {
      x: control.checked ? 26 : 4; y: 4
      width: 22; height: 22; radius: 11
      color: control.checked ? control.tokens.background : control.tokens.muted
      Behavior on x { NumberAnimation { duration: control.tokens.hoverDuration } }
    }
  }
}
