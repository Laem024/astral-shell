pragma ComponentBehavior: Bound
import QtQuick
import "../components" as Components
import "../../common" as Design

Item {
  id: root
  objectName: "window"
  required property Design.Theme tokens
  required property string title
  property bool available: true
  property bool expanded: false
  signal activated()
  readonly property bool hovered: hover.hovered
  property bool vertical: false
  property bool compact: false
  readonly property int contentPadding: tokens.gap
  property color ink: hover.hovered ? tokens.cyan : tokens.muted
  implicitWidth: vertical ? 52 : 192
  implicitHeight: vertical ? (compact ? 112 : 176) : 40
  Accessible.role: Accessible.Button
  Accessible.name: available ? "Window actions · " + title : "No active window"
  Accessible.expanded: expanded
  Accessible.onPressAction: if (root.available) root.activated()
  activeFocusOnTab: available
  Keys.onSpacePressed: if (root.available) root.activated()
  Keys.onReturnPressed: if (root.available) root.activated()
  Keys.onEnterPressed: if (root.available) root.activated()
  Behavior on ink { ColorAnimation { duration: root.tokens.hoverDuration } }
  Components.BarTile {
    anchors.fill: parent
    tokens: root.tokens
    hovered: root.hovered
    selected: root.expanded
    focused: root.activeFocus
  }
  Item {
    objectName: "focusComposition"
    width: root.vertical ? root.height : root.width; height: 40
    anchors.centerIn: parent
    rotation: root.vertical ? (root.tokens.settings.value.position === "right" ? 90 : -90) : 0
    Components.BarGlyph {
      x: root.contentPadding; y: 5
      width: 13; height: 13
      kind: "window"
      ink: root.ink
    }
    Text {
      id: focusLabel
      objectName: "windowFocus"
      x: root.contentPadding + 19; y: 6
      text: "FOCUS"
      color: root.ink
      font.family: root.tokens.mono
      font.pixelSize: 10
      font.letterSpacing: 0.8
    }
    Item {
      objectName: "windowCaret"
      x: focusLabel.x + focusLabel.implicitWidth + 4; y: 7
      width: 8; height: 7
      visible: root.available && (root.hovered || root.expanded)
      opacity: root.hovered ? 1 : 0.7
      rotation: root.expanded ? 180 : 0
      Behavior on opacity { NumberAnimation { duration: root.tokens.hoverDuration } }
      Behavior on rotation { NumberAnimation { duration: root.tokens.hoverDuration } }
      Rectangle { x: 0; y: 2; width: 5; height: 1; radius: 0.5; rotation: 30; color: root.ink }
      Rectangle { x: 3; y: 2; width: 5; height: 1; radius: 0.5; rotation: -30; color: root.ink }
    }
    Text {
      objectName: "windowTitle"
      x: root.contentPadding; y: 20
      width: Math.max(0, parent.width - 2 * root.contentPadding)
      text: root.title
      textFormat: Text.PlainText
      color: root.hovered ? root.tokens.cyan : root.tokens.text
      font.family: root.tokens.font
      font.pixelSize: 13
      maximumLineCount: 1
      elide: Text.ElideRight
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
    }
  }
  HoverHandler { id: hover }
  TapHandler { enabled: root.available; onTapped: root.activated() }
}
