import QtQuick
import Quickshell
import Quickshell.Io
import "." as Common

ShellRoot {
  id: root
  property bool active: false
  property string error: ""
  property bool wanted: false
  property double started: Date.now()
  FileView {
    id: preference
    path: Common.Paths.state + "/caffeine"
    blockLoading: true
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.update()
    onLoadFailed: Qt.callLater(() => Qt.quit())
  }
  function update() {
    wanted = preference.text().trim() === "on";
    if (!wanted) { inhibitor.running = false; Qt.quit(); }
    else if (!inhibitor.running) inhibitor.running = true;
  }
  Component.onCompleted: { Quickshell.watchFiles = false; update(); }
  // Idle inhibition never suppresses logind's lid policy. Sleep remains usable.
  Process {
    id: inhibitor
    command: ["systemd-inhibit", "--what=idle", "--mode=block", "--who=astral-caffeine", "--why=Keep the session active", "sleep", "infinity"]
    onExited: { root.active = false; root.error = "Idle inhibitor exited."; retry.restart(); }
  }
  Timer { id: retry; interval: 3000; onTriggered: if (root.wanted) inhibitor.running = true }
  Common.Command { id: check }
  Timer {
    interval: 1000; running: root.wanted; repeat: true; triggeredOnStart: true
    onTriggered: if (!check.running) check.run(["busctl", "--system", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "ListInhibitors"], (code, output) => {
      try {
        const rows = JSON.parse(output).data[0];
        root.active = code === 0 && inhibitor.running && rows.some(row => row[0] === "idle" && row[1] === "astral-caffeine" && row[3] === "block" && Number(row[5]) === Number(inhibitor.processId));
        root.error = root.active ? "" : "Logind has not confirmed the inhibitor.";
      } catch (_) { root.active = false; root.error = "Cannot verify logind inhibitors."; }
    })
  }
  IpcHandler {
    target: "caffeine"
    function status(): string { return JSON.stringify({active: root.active, wanted: root.wanted, error: root.error}); }
  }
}
