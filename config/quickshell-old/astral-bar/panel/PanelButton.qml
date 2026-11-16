import QtQuick
import QtQuick.Controls
import "../design" as Design

Button {
  id: root
  required property Design.Theme tokens
  property bool selected: false
  property bool preview: false
  property bool destructive: false
  implicitHeight: 36
  leftPadding: 10
  rightPadding: 10
  focusPolicy: preview ? Qt.NoFocus : Qt.StrongFocus
  // Preview controls remain legible while explicitly exposing their unavailable state.
  enabled: !preview
  Accessible.name: text
  contentItem: Text {
    text: root.text
    textFormat: Text.PlainText
    color: root.destructive ? root.tokens.alert : root.selected ? root.tokens.cyan : root.tokens.text
    font { family: root.tokens.mono; pixelSize: 11 }
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }
  background: Rectangle {
    radius: 5
    color: root.selected || root.hovered ? Qt.alpha(root.tokens.cyan, 0.09) : "transparent"
    border.color: root.activeFocus ? root.tokens.cyan : root.tokens.border
    Rectangle {
      visible: root.selected
      width: 2; height: parent.height - 14
      x: 0; y: 7
      color: root.tokens.cyan
    }
  }


}
