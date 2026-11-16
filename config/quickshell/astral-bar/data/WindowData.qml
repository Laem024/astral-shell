pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Singleton {
  id: root
  readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
  readonly property var hyprlandWindow: Hyprland.activeToplevel
  readonly property bool available: activeWindow !== null
  readonly property bool floating: hyprlandWindow
    ? !!hyprlandWindow.lastIpcObject.floating : false
  readonly property string title: activeWindow
    ? (activeWindow.title || activeWindow.appId || "Untitled window")
    : "Desktop"
  property string pendingKillAddress: ""

  // Quickshell only refreshes lastIpcObject when it fetches the client list, so
  // the floating flag would stay at the value captured when the bar started.
  // Pull a new snapshot on every mode change and whenever the menu asks for it.
  function refreshFloating(): void {
    if (hyprlandWindow) Hyprland.refreshToplevels();
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "changefloatingmode" || event.name === "openwindow")
        root.refreshFloating();
    }
  }

  Component.onCompleted: refreshFloating()

  // Ask the client to close; it may still save its work or show a prompt.
  function close(): void {
    if (activeWindow) activeWindow.close();
  }

  // The dispatcher acts on the window Hyprland has focused, without a PID lookup.
  function toggleFloating(): void {
    if (!hyprlandWindow) return;
    Hyprland.dispatch(Hyprland.usingLua
      ? 'hl.dsp.window.float({ action = "toggle" })'
      : "togglefloating");
  }

  // Resolve the PID right before signalling it so a focus change between the
  // menu click and the query cannot target an unrelated process.
  function forceClose(): void {
    if (!available || !hyprlandWindow || killer.running) return;
    pendingKillAddress = hyprlandWindow.address.replace(/^0x/, "");
    killer.running = true;
  }

  Process {
    id: killer
    command: ["hyprctl", "-j", "activewindow"]
    stdout: StdioCollector { id: output }
    stderr: StdioCollector {}
    onExited: (code, status) => {
      if (code !== 0 || status !== 0) { root.pendingKillAddress = ""; return; }
      try {
        const info = JSON.parse(output.text);
        const address = String(info.address || "").replace(/^0x/, "");
        const pid = Math.trunc(Number(info.pid));
        if (root.pendingKillAddress && address === root.pendingKillAddress && pid > 0)
          Quickshell.execDetached(["kill", "-9", String(pid)]);
      } catch (_) {}
      root.pendingKillAddress = "";
    }
  }
}
