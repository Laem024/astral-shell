import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common" as Common

Scope {
  id: root
  required property var settings
  required property var tokens
  property var monitor: null
  property bool opened: false
  property real reveal: opened ? 1 : 0
  readonly property bool privacyReady: Common.Privacy.ready
  readonly property bool previews: settings.value.previews !== false
  readonly property var data: overviewData

  Behavior on reveal {
    NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic }
  }

  OverviewData { id: overviewData }

  function close(): void {
    opened = false;
  }

  function open(delta, screen, active): void {
    if (!privacyReady || Common.Privacy.blocked) return;
    if (opened) { data.selectRelative(delta); return; }
    const focused = Hyprland.focusedMonitor;
    monitor = screen
      || Quickshell.screens.find(item => focused && item.name === focused.name)
      || Quickshell.screens[0] || null;
    if (!monitor) return;
    data.watching = true;
    // The first press only reveals the view on the active workspace; the
    // selection moves with later Alt + Tab presses while the view is open.
    data.reload(0);
    Common.Overlays.dismiss("astral-overview");
    opened = true;
  }

  function toggle(screen, active): void {
    if (opened) { close(); return; }
    open(1, screen, active);
  }

  function activateSelected(): void {
    if (!opened) return;
    close();
    data.activate();
  }

  function activateWorkspace(workspaceId: int): void {
    if (!opened) return;
    close();
    data.activateWorkspace(workspaceId);
  }

  function activateWindow(address: string): void {
    if (!opened) return;
    close();
    data.activateWindow(address);
  }

  function moveWorkspaceToMonitor(workspaceId: int, monitorName: string): void {
    if (!opened) return;
    data.moveWorkspaceToMonitor(workspaceId, monitorName);
  }

  onOpenedChanged: {
    if (!opened) grab.active = false;
    else Qt.callLater(() => { if (root.opened && window.visible) grab.active = true; });
  }

  Connections {
    target: Common.Privacy
    function onBlockedChanged(): void { if (Common.Privacy.blocked) root.close(); }
  }
  Connections {
    target: Quickshell
    function onScreensChanged(): void {
      if (!Quickshell.screens.includes(root.monitor)) root.close();
    }
  }

  IpcHandler {
    target: "overview"
    function state(): string { return Common.Privacy.ready ? "ready" : "loading"; }
    function altTab(direction: string, active: string): string {
      if (!Common.Privacy.ready) return "loading";
      if (Common.Privacy.blocked) return "blocked";
      root.open(direction === "previous" ? -1 : 1, null, active);
      return "ok";
    }
    function toggle(monitor: string, active: string): string {
      if (!root.privacyReady) return "loading";
      root.toggle(Quickshell.screens.find(item => item.name === monitor) || null, active);
      return Common.Privacy.blocked ? "blocked" : "ok";
    }
    function close(): string { root.close(); return "ok"; }
    function activate(): string {
      if (!root.opened) return "inactive";
      root.activateSelected();
      return "ok";
    }
    function closeActive(): string {
      if (!root.opened && root.reveal <= 0) return "inactive";
      root.close();
      return "closed";
    }
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
    WlrLayershell.namespace: "astral-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onVisibleChanged: {
      if (visible) Qt.callLater(() => { if (window.visible && root.opened) grab.active = true; });
      else grab.active = false;
    }
    HyprlandFocusGrab {
      id: grab
      windows: [window]
      onCleared: root.close()
    }
    Rectangle {
      anchors.fill: parent
      opacity: root.reveal
      // Darker behind the top carousel so the bar underneath stays subdued,
      // while the rest of the desktop remains visible.
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.alpha(root.tokens.background, 0.92) }
        GradientStop { position: 0.42; color: Qt.alpha(root.tokens.background, 0.64) }
        GradientStop { position: 1.0; color: Qt.alpha(root.tokens.background, 0.48) }
      }
    }
    OverviewContent {
      id: content
      anchors.fill: parent
      tokens: root.tokens
      overview: root.data
      active: root.opened
      previews: root.previews
      onActivateRequested: root.activateSelected()
      onActivateWorkspaceRequested: workspaceId => root.activateWorkspace(workspaceId)
      onActivateWindowRequested: address => root.activateWindow(address)
      onMoveWorkspaceToMonitorRequested: (workspaceId, monitorName) =>
        root.moveWorkspaceToMonitor(workspaceId, monitorName)
      onCancelRequested: root.close()
    }
  }
}
