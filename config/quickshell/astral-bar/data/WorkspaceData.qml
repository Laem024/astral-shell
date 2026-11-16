import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
  id: root
  required property ShellScreen screen
  required property int count
  readonly property int slots: Math.max(1, count)
  readonly property HyprlandMonitor monitor: {
    // Re-resolve after hotplug, including when the screen arrives before IPC.
    const monitors = Hyprland.monitors.values;
    return screen && monitors.length ? Hyprland.monitorFor(screen) : null;
  }
  readonly property int normalId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0
  readonly property bool ready: monitor !== null && normalId > 0
  readonly property int blockStart: ready ? Math.floor((normalId - 1) / slots) * slots : 0
  readonly property int active: ready ? ((normalId - 1) % slots) + 1 : 0
  readonly property var workspaces: {
    const entries = [];
    const all = Hyprland.workspaces.values;
    for (let index = 0; index < slots; index++) {
      const id = blockStart + index + 1;
      const workspace = ready ? all.find(space => space.id === id) : null;
      entries.push({id: id, apps: workspace ? workspace.toplevels.values.length : 0});
    }
    return entries;
  }
  readonly property var visibleSpecial: monitor ? monitor.lastIpcObject.specialWorkspace : null
  readonly property string activeSpecial: ready && visibleSpecial && visibleSpecial.name
    ? visibleSpecial.name : ""
  readonly property var specials: {
    if (!activeSpecial) return [];
    const workspace = Hyprland.workspaces.values.find(space =>
      (visibleSpecial.id < 0 && space.id === visibleSpecial.id)
      || (space.monitor === monitor && (space.name === "special:" + specialName(activeSpecial)
        || (space.lastIpcObject.type === "special" && space.name === activeSpecial))));
    return [{name: activeSpecial, apps: workspace ? workspace.toplevels.values.length : 0}];
  }

  function specialName(name: string): string {
    return name === "special" ? "" : name.replace(/^special:/, "");
  }

  function luaString(value: string): string {
    // Lua has no JSON-style \u escapes. Three decimal digits also protect
    // control characters followed by digits from changing the string value.
    return '"' + value.replace(/[\\"\x00-\x1f\x7f]/g, character => {
      if (character === '\\' || character === '"') return '\\' + character;
      return '\\' + String(character.charCodeAt(0)).padStart(3, '0');
    }) + '"';
  }

  function focusMonitor(): void {
    Hyprland.dispatch("hl.dsp.focus({ monitor = " + monitor.id + " })");
  }

  function activate(id: int): void {
    if (!ready || id < blockStart + 1 || id > blockStart + slots) return;
    focusMonitor();
    // Global IDs follow an existing workspace on another monitor; never move it.
    Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
  }

  function closeSpecial(name: string): void {
    if (!ready || !activeSpecial || name !== activeSpecial) return;
    const target = specialName(name);
    focusMonitor();
    Hyprland.dispatch("hl.dsp.workspace.toggle_special(" + luaString(target) + ")");
  }

  // Let Hyprland finish populating its models before requesting a snapshot.
  // An early refresh can suppress its initial monitor-creation request.
  onMonitorChanged: {
    if (monitor) Qt.callLater(() => Hyprland.refreshMonitors());
  }
  Connections {
    target: Hyprland
    function onRawEvent(event: HyprlandEvent): void {
      // Special visibility has no dedicated monitor property. Refresh the IPC
      // snapshot on both legacy and v2 events, including close and move events.
      if (event.name === "activespecial" || event.name === "activespecialv2"
          || event.name === "moveworkspace" || event.name === "moveworkspacev2"
          || event.name === "destroyworkspace" || event.name === "destroyworkspacev2")
        Hyprland.refreshMonitors();
    }
  }
}
