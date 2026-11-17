import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common" as Common

Scope {
  id: root
  Common.PopupDismiss {
    id: dismissPolicy; opened: root.opened; ownerScreen: root.monitor
    contentRect: Qt.rect(0, 0, window.width, window.height)
    onDismiss: root.close()
  }
  required property var settings
  required property var tokens
  property var screens: Quickshell.screens
  onScreensChanged: if (!screens.includes(monitor)) close()
  property var monitor: null
  property bool opened: false
  property real reveal: opened ? 1 : 0
  Behavior on reveal {
    NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic }
  }
  onOpenedChanged: {
    if (!opened) grab.active = false;
    else Qt.callLater(() => { if (root.opened && window.visible) grab.active = true; });
  }
  function close() { opened = false; }
  function closeActive() {
    if (Common.Privacy.blocked) return "blocked";
    // Keep consuming the close until the fading surface has disappeared.
    if (!opened && reveal <= 0) return "inactive";
    close(); return "closed";
  }
  function toggle(screen) {
    if (Common.Privacy.blocked || !launcherService.ready) return;
    if (opened) { close(); return; }
    const active = Hyprland.focusedMonitor;
    monitor = screen || root.screens.find(s => active && s.name === active.name) || root.screens[0] || null;
    if (!monitor) return;
    Common.Overlays.dismiss("astral-launcher");
    opened = true;
    Qt.callLater(() => { if (root.opened) content.reset(); });
  }
  IpcHandler {
    target: "launcher"
    function isOpen(): bool { return root.opened; }
    function state(): string { return root.privacyReady && launcherService.ready ? "ready" : "loading"; }
    function toggle(monitor: string): string {
      if (!root.privacyReady || !launcherService.ready) return "loading";
      root.toggle(root.screens.find(s => s.name === monitor) || null);
      return Common.Privacy.blocked ? "blocked" : "ok";
    }
    function close(): string { root.close(); return "ok"; }
    function closeActive(): string { return root.closeActive(); }
  }
  // Privacy starts blocked until logind confirms the unlocked session.
  readonly property bool privacyReady: Common.Privacy.ready
  Connections {
    target: Common.Privacy
    function onBlockedChanged() { if (Common.Privacy.blocked) root.close(); }
  }
  LauncherService { id: launcherService; settings: root.settings; onAccepted: root.close() }
  // qmllint disable uncreatable-type
  PanelWindow {
    id: window
    screen: root.monitor
    visible: (root.opened || root.reveal > 0) && !Common.Privacy.blocked
    implicitWidth: root.monitor ? root.monitor.width : 1
    implicitHeight: root.monitor ? root.monitor.height : 1
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "astral-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onVisibleChanged: {
      if (visible) Qt.callLater(() => { if (window.visible && root.opened) grab.active = true; });
      else grab.active = false;
    }
    HyprlandFocusGrab {
      id: grab
      windows: [window].concat(dismissPolicy.surfaces)
      onCleared: root.close()
    }
    MouseArea { anchors.fill: parent; onClicked: root.close() }
    Rectangle {
      anchors.fill: parent
      color: Qt.alpha(root.tokens.background, 0.58)
      opacity: root.reveal
    }
    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Math.max(1, Math.min(620, (window.width - 48) / root.tokens.scale))
      height: Math.max(1, Math.min(560, (window.height - 48) / root.tokens.scale))
      scale: root.tokens.scale * (0.97 + 0.03 * root.reveal)
      transformOrigin: Item.Center
      color: root.tokens.surface; radius: root.tokens.panelRadius; border.width: 1; border.color: root.tokens.border
      opacity: root.reveal
      enabled: root.opened
      // Consume clicks in the card so only the surrounding area dismisses it.
      MouseArea { anchors.fill: parent }
      RoundedClip {
        anchors.fill: parent; anchors.margins: 1
        radius: card.radius - 1
        LauncherContent {
          id: content
          anchors.fill: parent
          service: launcherService; tokens: root.tokens
          onCloseRequested: root.close()
        }
      }
    }
  }
}
