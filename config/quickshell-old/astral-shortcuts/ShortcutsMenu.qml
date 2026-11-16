pragma ComponentBehavior: Bound
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
    id: dismissPolicy
    opened: root.opened
    ownerScreen: root.monitor
    contentRect: Qt.rect(0, 0, window.width, window.height)
    onDismiss: root.close()
  }
  required property var settings
  required property var tokens
  property var monitor: null
  property bool opened: false
  property real reveal: opened ? 1 : 0
  readonly property bool privacyReady: Data.SessionData.ready
  Behavior on reveal { NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic } }

  function close(): void {
    opened = false;
  }
  function toggle(screen): void {
    if (!Data.SessionData.ready || Data.SessionData.blocked) return;
    if (opened) { close(); return; }
    const active = Hyprland.focusedMonitor;
    monitor = screen || Quickshell.screens.find(s => active && s.name === active.name) || Quickshell.screens[0] || null;
    if (!monitor) return;
    dismissBar.running = true;
    dismissLauncher.running = true;
    dismissWallpaper.running = true;
    dismissClipboard.running = true;
    dismissSession.running = true;
    dismissOverview.running = true;
    Data.ShortcutsData.refresh();
    opened = true;
    Qt.callLater(() => { if (root.opened) content.reset(); });
  }
  onOpenedChanged: {
    content.active = opened;
    if (!opened) grab.active = false;
    else Qt.callLater(() => {
      if (!root.opened || !window.visible) return;
      grab.active = true;
      content.forceActiveFocus();
    });
  }

  IpcHandler {
    target: "shortcuts"
    function state(): string { return Data.SessionData.ready ? "ready" : "loading"; }
    function toggle(monitor: string): string {
      if (!Data.SessionData.ready) return "loading";
      root.toggle(Quickshell.screens.find(s => s.name === monitor) || null);
      return Data.SessionData.blocked ? "blocked" : "ok";
    }
    function close(): string { root.close(); return "ok"; }
    function closeActive(): string {
      if (!root.opened && root.reveal <= 0) return "inactive";
      root.close();
      return "closed";
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
    id: dismissClipboard
    command: ["astral-clipboard", "close"]
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
    id: dismissOverview
    command: ["astral-overview", "close"]
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
    WlrLayershell.namespace: "astral-shortcuts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onVisibleChanged: {
      if (visible) Qt.callLater(() => {
        if (!window.visible || !root.opened) return;
        grab.active = true;
        content.forceActiveFocus();
      });
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
      width: Math.max(1, Math.min(1180, (window.width - 48) / root.tokens.scale))
      height: Math.max(1, Math.min(780, (window.height - 48) / root.tokens.scale))
      scale: root.tokens.scale * (0.97 + 0.03 * root.reveal)
      transformOrigin: Item.Center
      color: root.tokens.surface
      radius: root.tokens.panelRadius
      border.width: 1
      border.color: root.tokens.border
      opacity: root.reveal
      enabled: root.opened
      MouseArea { anchors.fill: parent }
      Components.RoundedClip {
        anchors.fill: parent
        anchors.margins: 1
        radius: card.radius - 1

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.tokens.cyan, 0.055) }
            GradientStop { position: 0.42; color: "transparent" }
          }
        }

        Text {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: -24
          anchors.bottomMargin: -150
          text: "✦"
          color: Qt.alpha(root.tokens.cyan, 0.035)
          font {
            family: root.tokens.mono
            pixelSize: 340
          }
        }

        Rectangle {
          anchors.top: parent.top
          anchors.left: parent.left
          width: parent.width * 0.55
          height: 1
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.alpha(root.tokens.cyan, 0.5) }
            GradientStop { position: 1; color: "transparent" }
          }
        }

        ShortcutsContent {
          id: content
          anchors.fill: parent
          tokens: root.tokens
          active: root.opened
          onCloseRequested: root.close()
        }
      }
    }
  }
}
