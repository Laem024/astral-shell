import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
  id: root
  property bool ready: false
  property bool opened: false
  readonly property string directory: Quickshell.env("ASTRAL_SESSION_DIR")
  FileView { id: starts; path: root.directory + "/starts"; printErrors: false; blockLoading: true; blockWrites: true }
  FileView { id: calls; path: root.directory + "/calls"; printErrors: false; blockLoading: true; blockWrites: true }
  FileView { id: reply; path: root.directory + "/reply"; blockLoading: true }
  function record(text) { calls.reload(); calls.waitForJob(); calls.setText(calls.text() + text + "\n"); }
  function closeReply(target) { record(target); reply.reload(); reply.waitForJob(); return reply.text().trim() || "inactive"; }
  Component.onCompleted: { starts.setText(starts.text() + "start\n"); }
  Timer { interval: 150; running: true; onTriggered: root.ready = true }
  IpcHandler {
    target: "polkit"
    function closeActive(): string { return root.closeReply("polkit"); }
  }
  IpcHandler {
    target: "session"
    function close(): string { root.record("close session"); return "ok"; }
    function closeActive(): string { return root.closeReply("session"); }
  }
  IpcHandler {
    target: "launcher"
    function state(): string { return root.ready ? "ready" : "loading"; }
    function isOpen(): bool { return root.opened; }
    function toggle(monitor: string): string { root.record("toggle " + monitor); root.opened = !root.opened; return "ok"; }
    function close(): string { root.record("close launcher"); root.opened = false; return "ok"; }
    function closeActive(): string { return root.closeReply("launcher"); }
  }
  IpcHandler {
    target: "wallpaper-carousel"
    function close(): string { root.record("close carousel"); return "ok"; }
    function closeActive(): string { return root.closeReply("carousel"); }
  }
  IpcHandler {
    target: "wallpaper"
    function close(): string { root.record("close wallpaper"); return "ok"; }
    function closeActive(): string { return root.closeReply("wallpaper"); }
  }
  IpcHandler {
    target: "bar"
    function closePanels(): void { root.record("close bar"); }
    function closeActive(): string { return root.closeReply("bar"); }
  }
  IpcHandler {
    target: "clipboard"
    function close(): string { root.record("close clipboard"); return "ok"; }
    function closeActive(): string { return root.closeReply("clipboard"); }
  }
  IpcHandler {
    target: "overview"
    function close(): string { root.record("close overview"); return "ok"; }
    function closeActive(): string { return root.closeReply("overview"); }
  }
  IpcHandler {
    target: "shortcuts"
    function close(): string { root.record("close shortcuts"); return "ok"; }
    function closeActive(): string { return root.closeReply("shortcuts"); }
  }
}
