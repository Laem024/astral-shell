pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../common" as Common
import "WindowLogic.js" as WindowLogic

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

  // The panel can release focus before hyprctl replies. Resolve the captured
  // address in the client list instead of consulting the newly active window.
  function forceClose(): void {
    if (!hyprlandWindow || killer.running) return;
    const address = hyprlandWindow.address;
    if (!address) return;
    killer.run(["hyprctl", "-j", "clients"], (code, text, error) => {
      if (code !== 0) {
        console.warn("Force close: could not query Hyprland clients:", error);
        return;
      }
      const pid = WindowLogic.pidForAddress(text, address);
      if (pid > 1) Quickshell.execDetached(["kill", "-9", String(pid)]);
    });
  }

  Common.Command {
    id: killer
    timeout: 3000
  }
}
