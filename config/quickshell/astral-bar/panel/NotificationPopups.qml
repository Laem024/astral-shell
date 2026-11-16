pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../data" as Data
import "../../common" as Design

Scope {
  id: root
  required property Design.Theme tokens
  required property var settings
  readonly property var service: Data.NotificationData
  // Capture the focused output on receipt, then keep each popup on that output.
  Binding {
    target: root.service; property: "focusedScreen"
    value: {
      const monitor = Hyprland.focusedMonitor;
      const focused = monitor ? Quickshell.screens.find(screen => screen.name === monitor.name) : null;
      const outputs = ToplevelManager.activeToplevel ? Array.from(ToplevelManager.activeToplevel.screens) : [];
      return focused || outputs[0] || Quickshell.screens[0] || null;
    }
  }
  Variants {
    model: Quickshell.screens
    // qmllint disable uncreatable-type
    delegate: PanelWindow {
      id: window
      required property ShellScreen modelData
      readonly property var notices: root.service.popups.filter(popup =>
        (Quickshell.screens.includes(popup.screen) ? popup.screen : Quickshell.screens[0]) === modelData)
      screen: modelData
      Component.onCompleted: root.service.surfaces = root.service.surfaces.concat([window])
      Component.onDestruction: root.service.surfaces = root.service.surfaces.filter(surface => surface !== window)
      // Keep the native surface mapped: showing another Qt window can dismiss
      // a grabbed PopupWindow even when that surface rejects keyboard focus.
      visible: true
      mask: Region {
        width: window.notices.length > 0 ? window.width : 0
        height: window.notices.length > 0 ? window.height : 0
      }
      color: "transparent"
      anchors { top: true; right: true }
      // We position relative to the physical output and account for our bar
      // exactly once, instead of adding its exclusive zone a second time.
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "astral-notifications"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      readonly property real factor: root.tokens.scale
      readonly property real topGap: root.settings.value.position === "top"
        ? root.tokens.horizontalSize * factor + root.settings.value.margin : 0
      readonly property real rightGap: root.settings.value.position === "right"
        ? root.tokens.verticalSize * factor + root.settings.value.margin : 0
      readonly property real leftGap: root.settings.value.position === "left"
        ? root.tokens.verticalSize * factor + root.settings.value.margin : 0
      // qmllint disable missing-property
      margins { top: window.topGap + 12 * window.factor; right: window.rightGap + 12 * window.factor }
      // qmllint enable missing-property
      implicitWidth: Math.max(1, Math.min(380 * factor, modelData.width - rightGap - leftGap - 24 * factor))
      implicitHeight: Math.max(1, Math.min((notices.length > 0 ? stack.implicitHeight * factor : 1), modelData.height - topGap - 24 * factor
        - (root.settings.value.position === "bottom" ? root.tokens.horizontalSize * factor + root.settings.value.margin : 0)))
      ScrollView {
        id: viewport
        visible: window.notices.length > 0
        width: window.width / window.factor; height: window.height / window.factor
        scale: window.factor; transformOrigin: Item.TopLeft
        contentWidth: availableWidth; clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
          id: stack
          width: viewport.availableWidth; spacing: 10
          Repeater {
            model: window.notices
            NotificationCard {
              required property var modelData
              tokens: root.tokens; entry: modelData.entry; popup: true
            }
          }
        }
      }
    }
  }
}
