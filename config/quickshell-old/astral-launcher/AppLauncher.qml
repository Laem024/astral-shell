import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "data" as Data
import "components" as Components

Scope {
  id: root
  Components.PopupDismiss {
    id: dismissPolicy; opened: root.opened; ownerScreen: root.monitor
    contentRect: Qt.rect(0, 0, window.width, window.height)
    onDismiss: root.close()
  }
  required property var settings
  required property var tokens
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
  function toggle(screen) {
    if (Data.SessionData.blocked) return;
    if (opened) { close(); return; }
    const active = Hyprland.focusedMonitor;
    monitor = screen || Quickshell.screens.find(s => active && s.name === active.name) || Quickshell.screens[0] || null;
    if (!monitor) return;
    closePanels.running = true;
    closeWallpaper.running = true;
    closeClipboard.running = true;
    closeSession.running = true;
    closeOverview.running = true;
    closeShortcuts.running = true;
    opened = true;
    Qt.callLater(() => { if (root.opened) content.reset(); });
  }
  IpcHandler {
    target: "launcher"
    function isOpen(): bool { return root.opened; }
    function state(): string { return root.privacyReady ? "ready" : "loading"; }
    function toggle(monitor: string): string {
      if (!root.privacyReady) return "loading";
      root.toggle(Quickshell.screens.find(s => s.name === monitor) || null);
      return Data.SessionData.blocked ? "blocked" : "ok";
    }
    function close(): string { root.close(); return "ok"; }
    function closeActive(): string {
      // Consume repeated close requests until the exit animation finishes.
      if (!root.opened && root.reveal <= 0) return "inactive";
      root.close();
      return "closed";
    }
  }
  // SessionData starts blocked until its first runtime-marker probe finishes.
  readonly property bool privacyReady: Data.SessionData.ready
  Process {
    id: closeWallpaper
    command: ["astral-wallpaper", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: closeClipboard
    command: ["astral-clipboard", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: closeSession
    command: ["astral-session", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: closeOverview
    command: ["astral-overview", "close"]
    // The overview may not be running; closing it never starts it.
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: closeShortcuts
    command: ["astral-shortcuts", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: closePanels
    command: ["astral-bar", "close-panels"]
    // The launcher also works when no bar instance exists.
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Connections {
    target: Data.SessionData
    function onBlockedChanged() { if (Data.SessionData.blocked) root.close(); }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() { if (!Quickshell.screens.includes(root.monitor)) root.close(); }
  }
  LauncherService { id: launcherService; settings: root.settings; onAccepted: root.close() }
  // qmllint disable uncreatable-type
  PanelWindow {
    id: window
    screen: root.monitor
    visible: (root.opened || root.reveal > 0) && !Data.SessionData.blocked
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
      width: Math.max(1, Math.min(1060, (window.width - 24) / root.tokens.scale))
      height: Math.max(1, Math.min(700, (window.height - 24) / root.tokens.scale))
      scale: root.tokens.scale * (0.97 + 0.03 * root.reveal)
      transformOrigin: Item.Center
      color: root.tokens.surface; radius: 22; border.color: root.tokens.border
      opacity: root.reveal
      enabled: root.opened
      // Consume clicks in the card so only the surrounding area dismisses it.
      MouseArea { anchors.fill: parent }
      Components.RoundedClip {
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
