import QtQuick
import "components" as Components
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "data" as Data

Scope {
  id: root
  Components.PopupDismiss {
    id: dismissPolicy; opened: root.opened; ownerScreen: root.monitor
    contentRect: Qt.rect(0, 0, window.width, window.height)
    onDismiss: root.close()
  }
  required property var service
  required property var tokens
  property bool opened: false
  property var monitor: null
  property real reveal: opened ? 1 : 0
  Behavior on reveal { NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic } }
  function close() { opened = false; }
  function toggle(name) {
    if (service.blocked || !service.ready) return;
    if (opened) { close(); return; }
    const focused = Hyprland.focusedMonitor;
    monitor = Quickshell.screens.find(s => s.name === name) || Quickshell.screens.find(s => focused && s.name === focused.name) || Quickshell.screens[0] || null;
    if (!monitor) return;
    dismiss.running = true; opened = true; service.refresh();
    content.targetMonitor = monitor.name;
    Qt.callLater(content.reset);
  }
  onOpenedChanged: {
    if (!opened) { grab.active = false; content.selected = null; content.dismissConfirmation(); }
    else Qt.callLater(() => { if (root.opened && window.visible) grab.active = true; });
  }
  Connections {
    target: root.service
    function onBlockedChanged() { if (root.service.blocked) root.close(); }
    function onScreensChanged() { if (!Quickshell.screens.includes(root.monitor)) root.close(); }
  }
  Process {
    id: dismiss
    command: ["bash", decodeURIComponent(Qt.resolvedUrl("session.sh").toString().replace(/^file:\/\//, "")), "dismiss-others"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  IpcHandler {
    target: "wallpaper"
    function state(): string { return root.service.ready && Data.SessionData.ready ? "ready" : "loading"; }
    function toggle(monitor: string): string { root.toggle(monitor); return root.service.blocked ? "blocked" : "ok"; }
    function close(): void { root.close(); }
    function closeActive(): string {
      if (!root.opened && root.reveal <= 0) return "inactive";
      root.close(); return "closed";
    }
  }
  // qmllint disable uncreatable-type
  PanelWindow {
    id: window
    screen: root.monitor
    visible: (root.opened || root.reveal > 0) && !root.service.blocked
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "astral-wallpaper-selector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onVisibleChanged: {
      if (visible) Qt.callLater(() => { if (root.opened && window.visible) grab.active = true; });
      else grab.active = false;
    }
    HyprlandFocusGrab { id: grab; windows: [window].concat(dismissPolicy.surfaces); onCleared: root.close() }
    Rectangle { anchors.fill: parent; color: Qt.alpha(root.tokens.background, 0.58); opacity: root.reveal }
    MouseArea { anchors.fill: parent; onClicked: root.close() }
    Item {
      anchors.centerIn: parent
      width: Math.max(1, Math.min(1320, (window.width - 24) / root.tokens.scale))
      height: Math.max(1, Math.min(840, (window.height - 24) / root.tokens.scale))
      scale: root.tokens.scale * (0.97 + 0.03 * root.reveal)
      opacity: root.reveal; enabled: root.opened
      MouseArea { anchors.fill: parent }
      WallpaperContent { id: content; anchors.fill: parent; service: root.service; tokens: root.tokens; onCloseRequested: root.close() }
    }
  }
}
