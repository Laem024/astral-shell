pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "data" as Data
import "../common" as Common
import "../common" as Design
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
  readonly property FrameGeometry frameGeometry: FrameGeometry { settings: root.settings; tokens: root.tokens }
  // Only FrameEdge owns reservations. Setting exclusiveZone here would switch
  // exclusionMode back to Normal and move the bar inside the reserved frame.
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Top
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
    top: root.settings.value.position !== "bottom" ? root.frameGeometry.margin : 0
    bottom: root.settings.value.position !== "top" ? root.frameGeometry.margin : 0
    left: root.settings.value.position !== "right" ? root.frameGeometry.margin : 0
    right: root.settings.value.position !== "left" ? root.frameGeometry.margin : 0
  }
  // qmllint enable missing-property
  implicitWidth: tokens.verticalSize * tokens.scale
  implicitHeight: tokens.horizontalSize * tokens.scale
  Rectangle { anchors.fill: parent; visible: root.frameGeometry.active; color: root.tokens.surface }
  BarContent {
    id: content
    enabled: !Data.SessionData.blocked
    visible: !Data.SessionData.blocked
    x: root.vertical ? 0 : root.settings.value.margin - root.frameGeometry.margin
    y: root.vertical ? root.settings.value.margin - root.frameGeometry.margin : 0
    width: (root.width - 2 * x) / root.tokens.scale
    height: (root.height - 2 * y) / root.tokens.scale
    scale: root.tokens.scale
    transformOrigin: Item.TopLeft
    settings: root.settings
    tokens: root.tokens
    vertical: root.vertical
    navigation: root.navigation
    monitor: root.modelData
    onLauncherRequested: if (Common.SettingsData.value.providers.launcher.length) launcherRequest.startDetached()
    nativeWindow: root
  }
  Variants {
    model: ["top", "bottom", "left", "right"]
    delegate: FrameEdge {
      required property string modelData
      monitor: root.modelData
      geometry: root.frameGeometry
      edge: modelData
      surfaceColor: root.tokens.surface
    }
  }
  Process {
    id: launcherRequest
    command: Common.SettingsData.value.providers.launcher.concat([root.modelData.name])
  }
  Panel.NativePanel { id: nativePanel; navigation: root.navigation; settings: root.settings; tokens: root.tokens; barWindow: root; owner: content }
}
