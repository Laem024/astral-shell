import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
  id: root
  property bool ready: false
  FileView { id: starts; path: Quickshell.env("ASTRAL_SESSION_DIR") + "/starts"; printErrors: false; blockLoading: true; blockWrites: true }
  FileView { id: toggles; path: Quickshell.env("ASTRAL_SESSION_DIR") + "/toggles"; printErrors: false; blockLoading: true; blockWrites: true }
  Component.onCompleted: starts.setText(starts.text() + "start\n")
  Timer { interval: 150; running: true; onTriggered: root.ready = true }
  IpcHandler {
    target: "wallpaper"
    function state(): string { return root.ready ? "ready" : "loading"; }
    function toggle(monitor: string): string { toggles.setText(toggles.text() + "selector " + monitor + "\n"); return "ok"; }
    function close(): void {}
    function closeActive(): string { return "inactive"; }
  }
  IpcHandler {
    target: "wallpaper-carousel"
    function state(): string { return root.ready ? "ready" : "loading"; }
    function toggle(monitor: string): string { toggles.setText(toggles.text() + "carousel " + monitor + "\n"); return "ok"; }
    function close(): void {}
    function closeActive(): string { return "inactive"; }
  }
}
