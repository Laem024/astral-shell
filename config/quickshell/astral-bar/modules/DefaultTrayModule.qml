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
  function toggle(): void {
    if (navigation.tray && navigation.owner === panel) navigation.close();
    else { navigation.anchor = root; navigation.openTray(panel); }
  }
  readonly property bool expanded: navigation.tray && navigation.owner === panel
  readonly property bool hovered: hover.hovered
  readonly property color ink: hovered || expanded ? tokens.cyan : tokens.text

  implicitWidth: 36
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
  ToolTip.visible: hovered
  ToolTip.text: "Background applications"
  ToolTip.delay: 650
  Components.BarTile {
    anchors.fill: parent
    tokens: root.tokens
    hovered: root.hovered
    selected: root.expanded
    focused: root.activeFocus
  }
  Components.StatusGlyph {
    objectName: "trayArrow"
    anchors.centerIn: parent
    width: 19; height: 19
    kind: "tray"
    ink: root.ink
  }
  HoverHandler { id: hover }
  TapHandler { onTapped: root.toggle() }

}
