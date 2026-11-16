pragma ComponentBehavior: Bound
import "data" as CommonShortcuts
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common" as Common

Scope {
  id: root
  Common.PopupDismiss {
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
  readonly property bool privacyReady: Common.Privacy.ready
  Behavior on reveal { NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic } }

  function close(): void {
    opened = false;
  }
  function toggle(screen): void {
    if (!Common.Privacy.ready || Common.Privacy.blocked) return;
    if (opened) { close(); return; }
    const active = Hyprland.focusedMonitor;
    monitor = screen || Quickshell.screens.find(s => active && s.name === active.name) || Quickshell.screens[0] || null;
    if (!monitor) return;
    CommonShortcuts.ShortcutsData.refresh();
    Common.Overlays.dismiss("astral-shortcuts");
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
    function state(): string { return Common.Privacy.ready ? "ready" : "loading"; }
    function toggle(monitor: string): string {
      if (!Common.Privacy.ready) return "loading";
      root.toggle(Quickshell.screens.find(s => s.name === monitor) || null);
      return Common.Privacy.blocked ? "blocked" : "ok";
    }
    function close(): string { root.close(); return "ok"; }
    function closeActive(): string {
      if (!root.opened && root.reveal <= 0) return "inactive";
      root.close();
      return "closed";
    }
  }

  Connections {
    target: Common.Privacy
    function onBlockedChanged() { if (Common.Privacy.blocked) root.close(); }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() { if (!Quickshell.screens.includes(root.monitor)) root.close(); }
  }

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
      Common.RoundedClip {
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
