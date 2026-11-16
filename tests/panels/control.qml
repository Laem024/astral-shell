import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
  id: root
  property bool ready: false
  readonly property string directory: Quickshell.env("ASTRAL_FIXTURE")
  FileView { id: starts; path: root.directory + "/starts"; printErrors: false; blockLoading: true; blockWrites: true }
  FileView { id: calls; path: root.directory + "/calls"; printErrors: false; blockLoading: true; blockWrites: true }
  FileView { id: reply; path: root.directory + "/reply"; blockLoading: true }
  function record(text) { calls.reload(); calls.waitForJob(); calls.setText(calls.text() + text + "\n"); }
  Component.onCompleted: starts.setText(starts.text() + "start\n")
  Timer { interval: 150; running: true; onTriggered: root.ready = true }
  IpcHandler {
    target: Quickshell.env("ASTRAL_PANEL")
    function state(): string { return root.ready ? "ready" : "loading"; }
    function toggle(mode: string): string { root.record("toggle " + mode); return "ok"; }
    function altTab(direction: string, active: string): string { root.record("alt-tab " + direction); return "ok"; }
    function clear(): string { root.record("clear"); return "ok"; }
    function close(): string { root.record("close"); return "ok"; }
    function closeActive(): string { reply.reload(); reply.waitForJob(); return reply.text().trim(); }
  }
}
