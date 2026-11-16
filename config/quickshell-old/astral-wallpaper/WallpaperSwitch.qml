import QtQuick
import QtQuick.Controls

// Large, quiet toggle for the settings cards.
Switch {
  id: control
  required property var tokens
  implicitWidth: 52; implicitHeight: 34
  padding: 0
  opacity: enabled ? 1 : 0.45
  indicator: Rectangle {
    x: 0; y: 3
    implicitWidth: 52; implicitHeight: 28; radius: 14
    color: control.checked ? control.tokens.cyan : control.tokens.surface
    border.color: control.activeFocus ? control.tokens.text : control.tokens.border
    Behavior on color { ColorAnimation { duration: control.tokens.hoverDuration } }
    Rectangle {
      x: control.checked ? 27 : 3; y: 3
      width: 22; height: 22; radius: 11
      color: control.checked ? control.tokens.background : control.tokens.muted
      Behavior on x { NumberAnimation { duration: control.tokens.hoverDuration } }
    }
  }
}
