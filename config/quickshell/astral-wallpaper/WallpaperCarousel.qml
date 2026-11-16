import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common" as Common

Scope {
  id: root
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
    dismiss.run(); opened = true; service.refresh();
  }
  function activate() {
    if (!opened || !window.visible) return;
    view.monitorName = monitor ? monitor.name : "";
    view.active = true;
    view.forceActiveFocus();
    grab.active = true;
  }
  onOpenedChanged: {
    if (!opened) { grab.active = false; view.active = false; return; }
    // Also covers reopening before the close animation finishes.
    Qt.callLater(activate);
  }
  Common.PopupDismiss {
    id: dismissPolicy; opened: root.opened; ownerScreen: root.monitor
    contentRect: Qt.rect(0, 0, window.width, window.height)
    onDismiss: root.close()
  }
  Connections {
    target: root.service
    function onBlockedChanged() { if (root.service.blocked) root.close(); }
    function onScreensChanged() { if (!Quickshell.screens.includes(root.monitor)) root.close(); }
  }
  DismissPeers { id: dismiss }
  IpcHandler {
    target: "wallpaper-carousel"
    function state(): string { return root.service.ready && Common.Privacy.ready ? "ready" : "loading"; }
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
    WlrLayershell.namespace: "astral-wallpaper-carousel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onVisibleChanged: {
      if (visible) Qt.callLater(root.activate);
      else { grab.active = false; view.active = false; }
    }
    HyprlandFocusGrab { id: grab; windows: [window].concat(dismissPolicy.surfaces); onCleared: root.close() }
    Rectangle {
      anchors.fill: parent
      opacity: root.reveal
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.alpha(root.tokens.background, 0.92) }
        GradientStop { position: 0.42; color: Qt.alpha(root.tokens.background, 0.62) }
        GradientStop { position: 1.0; color: Qt.alpha(root.tokens.background, 0.94) }
      }
    }
    MouseArea { anchors.fill: parent; onClicked: root.close() }
    Item {
      anchors.centerIn: parent
      width: Math.max(1, Math.min(1440, (window.width - 48) / root.tokens.scale))
      height: Math.max(1, Math.min(800, (window.height - 48) / root.tokens.scale))
      scale: root.tokens.scale * (0.98 + 0.02 * root.reveal)
      opacity: root.reveal; enabled: root.opened
      MouseArea { anchors.fill: parent }
      WallpaperCarouselView {
        id: view
        anchors.fill: parent
        service: root.service
        tokens: root.tokens
        onCloseRequested: root.close()
      }
    }
  }
}
