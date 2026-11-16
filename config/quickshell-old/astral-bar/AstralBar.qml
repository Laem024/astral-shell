pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import "data" as Data
import "design" as Design
import "panel" as Panel

// Quickshell 0.3.2 selects a concrete panel backend at runtime. Its qmltypes
// expose the abstract interface; suppress only that metadata diagnostic.
// qmllint disable uncreatable-type
PanelWindow {
  id: root
  property var navigation: previewNavigation
  property alias panelPopup: nativePanel
  required property ShellScreen modelData
  required property var settings
  required property Design.Theme tokens
  Panel.PanelState { id: previewNavigation }
  readonly property bool vertical: settings.value.position === "left" || settings.value.position === "right"
  screen: modelData
  // Keep the layer surface and its reserved space stable across lock/unlock.
  // The compositor covers it with the opaque session-lock surfaces.
  visible: true
  color: "transparent"
  anchors {
    top: root.settings.value.position !== "bottom"
    bottom: root.settings.value.position !== "top"
    left: root.settings.value.position !== "right"
    right: root.settings.value.position !== "left"
  }
  // Only the margins on the anchored edges count toward the reserved zone.
  // Without this, a top bar would reserve its margin twice (top and bottom).
  // qmllint disable missing-property
  margins {
    top: root.settings.value.position !== "bottom" ? root.settings.value.margin : 0
    bottom: root.settings.value.position !== "top" ? root.settings.value.margin : 0
    left: root.settings.value.position !== "right" ? root.settings.value.margin : 0
    right: root.settings.value.position !== "left" ? root.settings.value.margin : 0
  }
  // qmllint enable missing-property
  implicitWidth: tokens.verticalSize * tokens.scale
  implicitHeight: tokens.horizontalSize * tokens.scale
  BarContent {
    id: content
    enabled: !Data.SessionData.blocked
    width: root.width / root.tokens.scale
    height: root.height / root.tokens.scale
    scale: root.tokens.scale
    transformOrigin: Item.TopLeft
    settings: root.settings
    tokens: root.tokens
    vertical: root.vertical
    navigation: root.navigation
    monitor: root.modelData
    onLauncherRequested: launcherRequest.running = true
    nativeWindow: root
  }
  Process {
    id: launcherRequest
    command: ["astral-launcher", root.modelData.name]
  }
  Panel.NativePanel { id: nativePanel; navigation: root.navigation; settings: root.settings; tokens: root.tokens; barWindow: root; owner: content }
}
