pragma ComponentBehavior: Bound
import QtQuick
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
  Item {
    objectName: "focusComposition"
    width: root.vertical ? root.height : root.width; height: 40
    anchors.centerIn: parent
    rotation: root.vertical ? (root.tokens.settings.value.position === "right" ? 90 : -90) : 0
    Text {
      id: focusLabel
      objectName: "windowFocus"
      x: 12; y: 5
      text: "FOCUS"
      color: root.ink
      font.family: root.tokens.mono
      font.pixelSize: 8
      font.letterSpacing: 0.8
    }
    Item {
      objectName: "windowCaret"
      x: focusLabel.x + focusLabel.implicitWidth + 4; y: 6
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
      x: 12; y: 19; width: Math.max(0, parent.width - (root.vertical ? 24 : 32))
      text: root.title
      textFormat: Text.PlainText
      color: root.hovered ? root.tokens.cyan : root.tokens.text
      font.family: root.tokens.font
      font.pixelSize: 12
      maximumLineCount: 1
      elide: Text.ElideRight
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
    }
  }
  HoverHandler { id: hover }
  TapHandler { enabled: root.available; onTapped: root.activated() }
}
