pragma ComponentBehavior: Bound
import QtQuick
import "../../common" as Common
import "../components" as Components
import Quickshell.Services.SystemTray
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../data" as Data
import "../../common" as Design

// A layer surface with an explicit focus group avoids Qt's global popup grab.
// Notification surfaces belong to the group but never receive keyboard focus.
// qmllint disable uncreatable-type
PanelWindow {
  id: root
  Common.PopupDismiss {
    id: dismissPolicy; opened: root.visible; ownerScreen: root.screen
    contentRect: Qt.rect(root.popupX, root.popupY, root.width, root.height)
    controlRect: Qt.rect(root.barX, root.barY, root.barWindow.width, root.barWindow.height)
    onDismiss: root.navigation.close()
  }
  required property var navigation
  required property var settings
  required property Design.Theme tokens
  required property var barWindow
  required property Item owner
  readonly property string edge: settings.value.position
  readonly property real factor: tokens.scale
  readonly property bool tray: navigation ? navigation.tray : false
  readonly property bool menu: navigation ? navigation.windowMenu : false
  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property real barX: edge === "right" ? barWindow.screen.width - barWindow.frameGeometry.margin - barWindow.width : barWindow.frameGeometry.margin
  readonly property real barY: edge === "bottom" ? barWindow.screen.height - barWindow.frameGeometry.margin - barWindow.height : barWindow.frameGeometry.margin
  readonly property point control: navigation && navigation.anchor ? navigation.anchor.mapToItem(barWindow.contentItem, navigation.anchor.width / 2, navigation.anchor.height / 2) : Qt.point(barWindow.width / 2, barWindow.height / 2)
  // The focused module's width in screen units. On a horizontal bar the menu
  // covers that same plate and starts at its left edge; vertical bars keep a
  // readable minimum because the module itself is only one bar wide.
  readonly property real anchorWidth: navigation && navigation.anchor ? navigation.anchor.width * factor : 0
  readonly property real menuWidth: Math.max((vertical ? 300 : 240) * factor, anchorWidth)
  readonly property var geometry: barWindow.frameGeometry
  readonly property real leftInset: geometry.reservation("left")
  readonly property real rightInset: geometry.reservation("right")
  readonly property real topInset: geometry.reservation("top")
  readonly property real bottomInset: geometry.reservation("bottom")
  function clamp(value: real, maximum: real): real { return Math.max(0, Math.min(value, Math.max(0, maximum))); }
  implicitWidth: Math.max(1, Math.min((menu ? menuWidth : (tray ? 248 : 760) * factor), barWindow.screen.width - leftInset - rightInset - 6 * factor))
  // The tray cap fits four complete 72px rows plus its header and margins, so
  // scrolling only appears once a fifth row would be needed.
  implicitHeight: Math.max(1, Math.min((menu
    ? Math.max(120, (contentLoader.item ? (contentLoader.item as Item).implicitHeight : 176) + 32)
    : tray ? Math.min(364, (contentLoader.item ? (contentLoader.item as Item).implicitHeight : 108) + 32) : 760) * factor, barWindow.screen.height - topInset - bottomInset - 6 * factor))
  readonly property real popupX: leftInset + clamp((edge === "left" ? leftInset + 6 * factor
    : edge === "right" ? barWindow.screen.width - rightInset - width - 6 * factor
    : menu && navigation && navigation.anchor ? barX + control.x - anchorWidth / 2
    : barX + control.x - width / 2) - leftInset, barWindow.screen.width - leftInset - rightInset - width)
  readonly property real popupY: topInset + clamp((edge === "top" ? topInset + 6 * factor : edge === "bottom" ? barWindow.screen.height - bottomInset - height - 6 * factor : barY + control.y - height / 2) - topInset, barWindow.screen.height - topInset - bottomInset - height)
  screen: barWindow.screen
  anchors { top: true; left: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "astral-panel"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  // qmllint disable missing-property
  margins { top: root.popupY; left: root.popupX }
  // qmllint enable missing-property
  HyprlandFocusGrab {
    id: inputGrab
    objectName: "panelFocusGrab"
    windows: [root, root.barWindow].concat(Data.NotificationData.surfaces, dismissPolicy.surfaces)
    onCleared: if (root.visible && root.navigation && root.navigation.owner === root.owner) root.navigation.close()
  }
  Connections {
    target: Data.SessionData
    function onBlockedChanged() { if (Data.SessionData.blocked && root.navigation) root.navigation.close(); }
  }
  visible: !Data.SessionData.blocked && navigation !== null && navigation.owner === owner && (navigation.destination !== "" || navigation.tray || navigation.windowMenu)
  color: "transparent"
  onVisibleChanged: {
    if (visible) Qt.callLater(() => { if (root.visible) inputGrab.active = true; });
    else { inputGrab.active = false; Data.CaptureData.panelHidden(); }
    if (!visible && navigation && navigation.owner === owner) navigation.close();
  }
  onEdgeChanged: if (navigation && navigation.owner === owner) navigation.close()
  Rectangle {
    id: frame
    width: root.width / root.factor; height: root.height / root.factor
    scale: root.factor; transformOrigin: Item.TopLeft
    radius: root.tokens.panelRadius; color: root.tokens.surface
    border.color: root.tokens.border; border.width: 1
    focus: true
    Keys.onEscapePressed: root.navigation.close()
    Loader {
      id: contentLoader
      focus: true
      active: root.visible
      anchors.fill: parent; anchors.margins: root.tokens.inset
      sourceComponent: root.menu ? windowMenu : root.tray ? trayContent : panelContent
    }
  }
  Component {
    id: panelContent
    PanelContent {
      tokens: root.tokens; settings: root.settings
      monitorName: root.screen ? root.screen.name : ""
      tab: root.navigation ? root.navigation.destination : "Control Center"
      onTabSelected: name => root.navigation.destination = name
      onCaptureRequested: root.navigation.close()
    }
  }
  Component {
    id: windowMenu
    WindowMenu {
      tokens: root.tokens
      onDismissed: root.navigation.close()
    }
  }
  Component {
    id: trayContent
    TrayContent {
      tokens: root.tokens
      items: SystemTray.items
      onCloseRequested: root.navigation.close()
    }
  }
}
