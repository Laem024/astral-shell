pragma ComponentBehavior: Bound
import QtQuick
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
  readonly property color ink: hovered ? tokens.cyan : tokens.muted

  implicitWidth: 40
  implicitHeight: 40
  Accessible.role: Accessible.Button
  Accessible.name: "Background applications"
  Accessible.onPressAction: root.toggle()
  onVisibleChanged: if (!visible && navigation && navigation.owner === panel) navigation.close()
  Accessible.expanded: expanded
  activeFocusOnTab: true
  Keys.onSpacePressed: root.toggle()
  Keys.onReturnPressed: root.toggle()
  Keys.onEnterPressed: root.toggle()
  Item {
    objectName: "trayArrow"
    width: 16; height: 16
    anchors.centerIn: parent
    rotation: (root.tokens.settings.value.position === "bottom" ? 180
      : root.tokens.settings.value.position === "left" ? -90
      : root.tokens.settings.value.position === "right" ? 90 : 0) + (root.expanded ? 180 : 0)
    Behavior on rotation { NumberAnimation { duration: root.tokens.hoverDuration } }
    Rectangle { x: 1; y: 7; width: 9; height: 2; radius: 1; rotation: 45; color: root.ink }
    Rectangle { x: 7; y: 7; width: 9; height: 2; radius: 1; rotation: -45; color: root.ink }
  }
  HoverHandler { id: hover }
  TapHandler { onTapped: root.toggle() }

}
