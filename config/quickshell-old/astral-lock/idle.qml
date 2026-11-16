import QtQuick
import Quickshell
import Quickshell.Io

// Separate from both the bar and the authentication process. No unlock API.
ShellRoot {
  id: root
  property bool idle: false
  Component.onCompleted: Quickshell.watchFiles = false
  function check(): void { if (idle && !probe.running && !prepare.running && !finalProbe.running && !suspend.running) probe.running = true; }
  IpcHandler {
    target: "idle"
    function begin(): void { root.idle = true; root.check(); }
    function cancel(): void { root.idle = false; Qt.quit(); }
  }
  Timer { interval: 30000; repeat: true; running: root.idle; onTriggered: root.check() }
  Process {
    id: probe
    command: ["timeout", "8", "bash", decodeURIComponent(Qt.resolvedUrl("media-idle.sh").toString().replace(/^file:\/\//, ""))]
    onExited: (code, status) => { if (root.idle && code === 0 && status === 0) prepare.running = true; }
  }
  Process {
    id: prepare
    command: ["astral-lock", "lock"]
    // A second probe closes the gap spent starting and drawing the lock.
    onExited: (code, status) => { if (root.idle && code === 0 && status === 0) finalProbe.running = true; }
  }
  Process {
    id: finalProbe
    command: probe.command
    onExited: (code, status) => { if (root.idle && code === 0 && status === 0) suspend.running = true; }
  }
  Process {
    id: suspend
    // logind enforces sleep inhibitors; do not force or ignore them.
    command: ["astral-lock", "auto-suspend"]
    onExited: root.idle = false
  }
}
