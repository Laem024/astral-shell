pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  // A failed probe never blocks authentication; only a positive lock report does.
  property bool blocked: false
  readonly property string helper: "astral-lock"

  Process {
    id: status
    command: [root.helper, "privacy"]
    stdout: StdioCollector { id: output }
    onExited: (code, exitStatus) => {
      if (code === 0 && exitStatus === 0) root.blocked = output.text.trim() !== "idle";
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
