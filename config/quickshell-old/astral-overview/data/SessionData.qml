pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  // A persistent runtime marker survives a failed locker and a view restart.
  property bool ready: false
  property bool blocked: true
  readonly property string helper: "astral-lock"

  Process {
    id: status
    command: [root.helper, "privacy"]
    stdout: StdioCollector { id: output }
    onExited: (code, exitStatus) => {
      root.blocked = code !== 0 || exitStatus !== 0 || output.text.trim() !== "idle";
      root.ready = true;
    }
  }
  Timer {
    interval: 500
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!status.running) status.running = true
  }
}
