pragma ComponentBehavior: Bound
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
  required property var tokens
  property var monitor: null
  property bool opened: false
  property real reveal: opened ? 1 : 0
  readonly property bool privacyReady: Common.SessionActions.ready
  Behavior on reveal { NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic } }

  function close() {
    opened = false;
  }
  function toggle(screen) {
    if (Common.SessionActions.blocked) return;
    if (opened) { close(); return; }
    const active = Hyprland.focusedMonitor;
    monitor = screen || Quickshell.screens.find(s => active && s.name === active.name) || Quickshell.screens[0] || null;
    if (!monitor) return;
    Common.Overlays.dismiss("astral-session");
    Common.SessionActions.error = "";
    opened = true;
    Qt.callLater(() => { if (root.opened) content.reset(); });
  }
  onOpenedChanged: {
    content.active = opened;
    if (!opened) grab.active = false;
    else Qt.callLater(() => { if (root.opened && window.visible) grab.active = true; });
  }

  IpcHandler {
    target: "session"
    function state(): string { return Common.SessionActions.ready ? "ready" : "loading"; }
    function toggle(monitor: string): string {
      if (!Common.SessionActions.ready) return "loading";
      root.toggle(Quickshell.screens.find(s => s.name === monitor) || null);
      return Common.SessionActions.blocked ? "blocked" : "ok";
    }
    function close(): string { root.close(); return "ok"; }
    function closeActive(): string {
      if (!root.opened && root.reveal <= 0) return "inactive";
      root.close();
      return "closed";
    }
  }

  Connections {
    target: Common.SessionActions
    function onBlockedChanged() { if (Common.SessionActions.blocked) root.close(); }
    function onCompleted(action) { root.close(); }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() { if (!Quickshell.screens.includes(root.monitor)) root.close(); }
  }

  // qmllint disable uncreatable-type
  PanelWindow {
    id: window
    screen: root.monitor
    visible: (root.opened || root.reveal > 0) && !Common.SessionActions.blocked
    implicitWidth: root.monitor ? root.monitor.width : 1
    implicitHeight: root.monitor ? root.monitor.height : 1
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "astral-session"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
      color: root.tokens.scrim
      opacity: root.reveal
    }
    MouseArea { anchors.fill: parent; onClicked: root.close() }
    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Math.max(1, Math.min(820, (window.width - 48) / root.tokens.scale))
      height: Math.max(1, Math.min(content.implicitHeight + 2, (window.height - 48) / root.tokens.scale))
      scale: root.tokens.scale * (0.97 + 0.03 * root.reveal)
      transformOrigin: Item.Center
      color: root.tokens.surface
      radius: root.tokens.panelRadius
      border.color: root.tokens.border
      opacity: root.reveal
      enabled: root.opened
      MouseArea { anchors.fill: parent }
      RoundedClip {
        anchors.fill: parent
        anchors.margins: 1
        radius: card.radius - 1
        SessionContent {
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
