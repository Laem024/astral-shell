import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design

// Shared control button. `tint` colours the selected state, `destructive` uses
// the alert tone, and `quiet` drops the outline for secondary row actions.
Button {
  id: root
  required property Design.Theme tokens
  property bool selected: false
  property bool preview: false
  property bool destructive: false
  property bool quiet: false
  property color tint: tokens.cyan
  property string symbol: ""
  readonly property color accent: destructive ? tokens.alert : tint
  readonly property color ink: destructive || selected ? accent : tokens.text
  implicitHeight: 38
  leftPadding: 14
  rightPadding: 14
  focusPolicy: preview ? Qt.NoFocus : Qt.StrongFocus
  Layout.minimumWidth: 0
  // Preview controls remain legible while explicitly exposing their unavailable state.
  enabled: !preview
  opacity: enabled || preview ? 1 : 0.4
  Accessible.name: text
  contentItem: RowLayout {
    spacing: 6
    Text {
      visible: root.symbol !== ""
      text: root.symbol
      textFormat: Text.PlainText
      color: root.accent
      font { family: root.tokens.mono; pixelSize: 13 }
    }
    Text {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      text: root.text
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: root.ink
      horizontalAlignment: root.symbol !== "" ? Text.AlignLeft : Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      font { family: root.tokens.font; pixelSize: 12; weight: Font.Medium }
    }
  }
  background: Rectangle {
    radius: root.tokens.rowRadius
    color: root.quiet
      ? (root.down || root.hovered ? Qt.alpha(root.accent, 0.08) : "transparent")
      : root.selected
        ? Qt.alpha(root.accent, root.down ? 0.28 : root.hovered ? 0.22 : 0.16)
        : root.down || root.hovered ? Qt.alpha(root.tokens.text, 0.08) : Qt.alpha(root.tokens.text, 0.03)
    border.width: root.activeFocus ? 2 : root.quiet ? 0 : 1
    border.color: root.activeFocus ? root.tokens.cyan
      : root.quiet ? "transparent"
      : root.selected ? Qt.alpha(root.accent, 0.45) : root.tokens.border
    Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
  }
}
