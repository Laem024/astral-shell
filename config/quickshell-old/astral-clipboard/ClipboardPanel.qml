import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "data" as Data
import "components" as Components
import "Logic.js" as Logic

Scope {
  id: root
  Components.PopupDismiss {
    id: dismissPolicy
    opened: root.opened
    ownerScreen: root.monitor
    contentRect: Qt.rect(0, 0, window.width, window.height)
    onDismiss: root.close()
  }
  required property var settings
  required property var service
  required property var tokens
  property bool opened: false
  property string mode: "paste"
  property var monitor: null
  property real reveal: opened ? 1 : 0
  readonly property bool privacyReady: Data.SessionData.ready
  Behavior on reveal { NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic } }

  function close() { opened = false; }
  function toggle(name) {
    if (Data.SessionData.blocked || !root.privacyReady || !root.service.ready) return;
    const next = name === "delete" ? "delete" : "paste";
    if (opened) {
      if (mode === next) { close(); return; }
      mode = next;
      content.reset();
      return;
    }
    const active = Hyprland.focusedMonitor;
    monitor = Quickshell.screens.find(s => active && s.name === active.name)
      || Quickshell.screens[0] || null;
    if (!monitor) return;
    service.error = "";
    dismissBar.running = true;
    dismissLauncher.running = true;
    dismissWallpaper.running = true;
    dismissSession.running = true;
    dismissOverview.running = true;
    dismissShortcuts.running = true;
    mode = next;
    opened = true;
    service.reload();
    Qt.callLater(() => { if (root.opened) content.reset(); });
  }
  function pasteCommand() {
    const shortcut = root.settings.value.pasteShortcut || { mods: "CTRL", key: "v" };
    return ["hyprctl", "dispatch", Logic.luaShortcut(shortcut.mods, shortcut.key)];
  }
  onOpenedChanged: {
    content.active = opened;
    if (!opened) {
      grab.active = false;
    } else {
      Qt.callLater(() => { if (root.opened && window.visible) grab.active = true; });
    }
  }
  Connections {
    target: root.service
    function onCopied() {
      const action = root.settings.value.enterAction;
      root.close();
      if (action !== "copy") pasteDelay.restart();
    }
  }
  Connections {
    target: Data.SessionData
    function onBlockedChanged() { if (Data.SessionData.blocked) root.close(); }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() { if (!Quickshell.screens.includes(root.monitor)) root.close(); }
  }
  Timer {
    id: pasteDelay
    interval: root.tokens.entryDuration + 80
    onTriggered: {
      sendPaste.command = root.pasteCommand();
      sendPaste.running = true;
    }
  }
  Process {
    id: sendPaste
    stdout: StdioCollector {}
    stderr: StdioCollector { id: pasteError }
    onExited: (code, status) => {
      if (code !== 0 || status !== 0) {
        root.service.error = pasteError.text.trim() || "Could not send the paste shortcut.";
      }
    }
  }
  Process {
    id: dismissBar
    command: ["astral-bar", "close-panels"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: dismissLauncher
    command: ["astral-launcher", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: dismissWallpaper
    command: ["astral-wallpaper", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: dismissOverview
    command: ["astral-overview", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: dismissSession
    command: ["astral-session", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: dismissShortcuts
    command: ["astral-shortcuts", "close"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  IpcHandler {
    target: "clipboard"
    function state(): string { return root.service.ready && Data.SessionData.ready ? "ready" : "loading"; }
    function toggle(mode: string): string {
      if (!root.privacyReady || !root.service.ready) return "loading";
      root.toggle(mode);
      return Data.SessionData.blocked ? "blocked" : "ok";
    }
    function close(): string { root.close(); return "ok"; }
    function closeActive(): string {
      if (!root.opened && root.reveal <= 0) return "inactive";
      root.close();
      return "closed";
    }
    function refresh(): string { root.service.reload(); return "ok"; }
  }
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
    WlrLayershell.namespace: "astral-clipboard"
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
    Rectangle {
      anchors.fill: parent
      color: Qt.alpha(root.tokens.background, 0.58)
      opacity: root.reveal
    }
    MouseArea { anchors.fill: parent; onClicked: root.close() }
    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Math.max(1, Math.min(980, (window.width - 24) / root.tokens.scale))
      height: Math.max(1, Math.min(680, (window.height - 24) / root.tokens.scale))
      scale: root.tokens.scale * (0.97 + 0.03 * root.reveal)
      transformOrigin: Item.Center
      color: root.tokens.surface
      radius: 22
      border.color: root.tokens.border
      opacity: root.reveal
      enabled: root.opened
      MouseArea { anchors.fill: parent }
      Components.RoundedClip {
        anchors.fill: parent
        anchors.margins: 1
        radius: card.radius - 1
        ClipboardContent {
          id: content
          anchors.fill: parent
          service: root.service
          tokens: root.tokens
          settings: root.settings
          mode: root.mode
          onCloseRequested: root.close()
          onAcceptRequested: item => {
            if (root.mode === "delete") root.service.remove(item.id);
            else root.service.copy(item);
          }
          onRemoveRequested: id => root.service.remove(id)
        }
      }
    }
  }
}
