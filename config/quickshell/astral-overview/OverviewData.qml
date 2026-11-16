import "../common" as Common
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "Logic.js" as Logic

Scope {
  id: root
  readonly property int count: Common.SettingsData.value.workspaceCount
  property int activeId: 0
  property int blockStart: 0
  property var workspaces: []
  property var monitors: []
  // The selection is always a workspace: open windows never reorder Alt + Tab.
  property int selectedIndex: -1
  property bool watching: false
  readonly property var selectedWorkspace: selectedIndex >= 0 && selectedIndex < workspaces.length
    ? workspaces[selectedIndex] : null
  readonly property int windowTotal: workspaces.reduce((total, space) => total + space.windows.length, 0)
  readonly property int blockEnd: blockStart + count
  property int pendingDirection: 1
  property bool pendingFromActive: false

  Component.onCompleted: rebuild()
  onCountChanged: rebuild()

  function currentActiveId(): int {
    const monitor = Hyprland.focusedMonitor;
    if (monitor && monitor.activeWorkspace && monitor.activeWorkspace.id > 0)
      return monitor.activeWorkspace.id;
    const focused = Hyprland.focusedWorkspace;
    if (focused && focused.id > 0) return focused.id;
    return -1;
  }

  function reload(direction): void {
    pendingDirection = Logic.direction(direction);
    pendingFromActive = true;
    rebuild();

  }

  function rebuild(): void {
    const size = Logic.count(count);
    const id = currentActiveId();
    const knownActive = id > 0;
    const anchor = knownActive ? id : 1;
    const all = Hyprland.workspaces.values || [];
    const previousId = selectedWorkspace ? selectedWorkspace.id : -1;
    const spaces = [];

    activeId = knownActive ? id : 0;
    blockStart = Logic.blockStart(anchor, size);
    const focusedMonitor = Hyprland.focusedMonitor;
    monitors = (Hyprland.monitors.values || []).slice()
      .sort((left, right) => (left.x - right.x) || (left.id - right.id))
      .map(monitor => ({
        id: monitor.id,
        name: monitor.name,
        focused: !!focusedMonitor && monitor.id === focusedMonitor.id
      }));
    for (const workspaceId of Logic.blockIds(anchor, size)) {
      const workspace = all.find(space => space.id === workspaceId) || null;
      const entries = Logic.sortWindows(workspace && workspace.toplevels
        ? workspace.toplevels.values : []).map(toplevel => ({
          toplevel,
          address: Logic.windowAddress(toplevel),
          appId: Logic.windowAppId(toplevel),
          title: Logic.windowTitle(toplevel),
          capture: toplevel.wayland,
          focusHistoryID: Logic.focusHistory(toplevel)
        }));
      spaces.push({
        id: workspaceId,
        current: workspaceId === id,
        exists: workspace !== null,
        monitorId: workspace && workspace.monitor ? workspace.monitor.id : -1,
        monitorName: workspace && workspace.monitor ? workspace.monitor.name : "",
        windows: entries
      });
    }

    workspaces = spaces;
    if (pendingFromActive) {
      if (knownActive) {
        selectFromActive(pendingDirection);
        pendingFromActive = false;
      } else {
        // Hyprland state may still be loading on the first launch. Keep the
        // request pending so the next focused workspace selects the active slot.
        selectedIndex = -1;
      }
    } else if (workspaces.length === 0 || previousId < 0) {
      selectedIndex = -1;
    } else {
      const index = workspaces.findIndex(space => space.id === previousId);
      selectedIndex = index >= 0 ? index : Logic.wrap(selectedIndex, workspaces.length);
    }
  }

  function selectFromActive(delta): void {
    if (workspaces.length === 0) { selectedIndex = -1; return; }
    selectedIndex = Logic.activeWorkspaceIndex(workspaces.map(space => space.id), activeId, delta);
  }

  function selectRelative(delta): void {
    if (workspaces.length === 0) return;
    selectedIndex = selectedIndex < 0
      ? (delta < 0 ? workspaces.length - 1 : 0)
      : Logic.wrap(selectedIndex + delta, workspaces.length);
  }

  function activate(): void {
    const workspace = selectedWorkspace;
    if (!workspace) return;
    // Revealing the view must not alter the session: releasing Alt on the
    // active workspace is a no-op instead of refocusing it.
    if (workspace.id === activeId) return;
    focusWorkspace(workspace.id);
  }

  function activateWorkspace(workspaceId): void {
    focusWorkspace(workspaceId);
  }

  function activateWindow(address): void {
    focusWindow(address);
  }

  function moveWindow(address, workspaceId): void {
    const target = Logic.windowAddress(address);
    if (!target || !windowExists(target)) return;
    const command = Logic.moveCommand(target, workspaceId, Hyprland.usingLua);
    if (!command) return;
    if (!Common.Privacy.ready || Common.Privacy.blocked) return;
    Hyprland.dispatch(command);
  }

  function moveWorkspaceToMonitor(workspaceId, monitorName): void {
    if (!(Hyprland.monitors.values || []).some(m => m.name === monitorName) || !workspaces.some(w => w.id === workspaceId)) return;
    const command = Logic.moveWorkspaceCommand(workspaceId, monitorName, Hyprland.usingLua);
    if (!command) return;
    if (!Common.Privacy.ready || Common.Privacy.blocked) return;
    Hyprland.dispatch(command);
  }

  function windowExists(address): bool {
    return (Hyprland.workspaces.values || []).some(space =>
      (space.toplevels ? space.toplevels.values : []).some(window => Logic.windowAddress(window) === address));
  }

  function focusWindow(address): void {
    const target = Logic.windowAddress(address);
    if (!target || !windowExists(target)) return;
    const workspace = workspaces.find(space =>
      space.windows.some(window => window.address === target));
    if (!workspace) return;
    if (workspace.monitorId >= 0) focusMonitor(workspace.monitorId);
    if (!Common.Privacy.ready || Common.Privacy.blocked) return;
    Hyprland.dispatch('hl.dsp.focus({ window = '
      + Logic.luaString("address:" + target) + ' })');
  }

  function focusWorkspace(workspaceId): void {
    if (!Number.isInteger(workspaceId) || workspaceId < 1) return;
    const workspace = (Hyprland.workspaces.values || []).find(space => space.id === workspaceId);
    if (workspace && workspace.monitor) focusMonitor(workspace.monitor.id);
    if (!Common.Privacy.ready || Common.Privacy.blocked) return;
    Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })");
  }

  function focusMonitor(monitorId): void {
    if (monitorId < 0 || !(Hyprland.monitors.values || []).some(m => m.id === monitorId)) return;
    if (!Common.Privacy.ready || Common.Privacy.blocked) return;
    Hyprland.dispatch("hl.dsp.focus({ monitor = " + monitorId + " })");
  }


  Connections {
    target: Hyprland
    function onRawEvent(event): void {
      if (!root.watching) return;
      if (["openwindow", "closewindow", "movewindow", "movewindowv2",
        "moveworkspace", "moveworkspacev2",
        "monitoradded", "monitoraddedv2", "monitorremoved"].includes(event.name))
        root.rebuild();
    }
    function onFocusedWorkspaceChanged(): void {
      if (root.watching && root.pendingFromActive) root.rebuild();
    }
    function onFocusedMonitorChanged(): void {
      if (root.watching && root.pendingFromActive) root.rebuild();
    }
  }
}
