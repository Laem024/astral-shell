pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../components" as Components
import "../../common" as Design

Item {
  id: root
  objectName: "tray"
  required property Design.Theme tokens
  required property Item panel
  required property var navigation
  property var nativeWindow: null
  property bool vertical: false
  property bool compact: false
  function toggle(): void {
    if (navigation.tray && navigation.owner === panel) navigation.close();
    else { navigation.anchor = root; navigation.openTray(panel); }
  }
  readonly property bool expanded: navigation.tray && navigation.owner === panel
  readonly property bool hovered: hover.hovered
  readonly property color ink: hovered || expanded ? tokens.cyan : tokens.text

  implicitWidth: compact ? 32 : 36
  implicitHeight: 36
  Accessible.role: Accessible.Button
  Accessible.name: "Background applications"
  Accessible.onPressAction: root.toggle()
  onVisibleChanged: if (!visible && navigation && navigation.owner === panel) navigation.close()
  Accessible.expanded: expanded
  activeFocusOnTab: true
  Keys.onSpacePressed: root.toggle()
  Keys.onReturnPressed: root.toggle()
  Keys.onEnterPressed: root.toggle()
  Components.BarTile {
    anchors.fill: parent
    tokens: root.tokens
    hovered: root.hovered
    selected: root.expanded
    focused: root.activeFocus
  }
  Components.BarGlyph {
    objectName: "trayArrow"
    anchors.centerIn: parent
    width: 20; height: 20
    kind: "tray"
    ink: root.ink
    rotation: (root.vertical ? (root.tokens.settings.value.position === "right" ? 90 : -90)
      : root.tokens.settings.value.position === "bottom" ? 180 : 0)
      + (root.expanded ? 180 : 0)
    Behavior on rotation { NumberAnimation { duration: root.tokens.hoverDuration } }
  }
  HoverHandler { id: hover }
  TapHandler { onTapped: root.toggle() }

}
