pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
  id: root
  required property var service
  required property var tokens
  required property var monitor
  signal cancelRequested()
  signal submitRequested(string value)
  visible: !service.blocked
  screen: monitor
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "astral-polkit"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  function focusInput() { content.focusInput(); }
  PolkitContent {
    id: content
    anchors.fill: parent
    service: root.service
    tokens: root.tokens
    onCancelRequested: root.cancelRequested()
    onSubmitRequested: value => root.submitRequested(value)
  }
}
