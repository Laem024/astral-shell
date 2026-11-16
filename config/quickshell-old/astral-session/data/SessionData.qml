pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Logic.js" as Logic

Singleton {
  id: root
  // A persistent runtime marker survives a failed locker and a menu restart.
  property bool ready: false
  property bool blocked: true
  property string error: ""
  property bool pending: false
  property string lastAction: ""
  readonly property string helper: "astral-lock"
  signal completed(string action)

  function perform(action: string): void {
    if (pending || !Logic.valid(action)) return;
    error = "";
    lastAction = action;
    pending = true;
    if (action === "lock" || action === "suspend") blocked = true;
    request.command = [helper, action];
    request.running = true;
  }

  Process {
    id: request
    stderr: StdioCollector { id: requestError }
    onExited: (code, status) => {
      const action = root.lastAction;
      root.lastAction = "";
      root.pending = false;
      if (code !== 0 || status !== 0) {
        root.error = requestError.text.trim() || "Could not complete the session action.";
      } else {
        root.completed(action);
      }
    }
  }
  Process {
    id: status
    command: [root.helper, "privacy"]
    stdout: StdioCollector { id: output }
    onExited: (code, exitStatus) => {
      if (!root.pending) root.blocked = code !== 0 || exitStatus !== 0 || output.text.trim() !== "idle";
      root.ready = true;
    }
  }
  Timer {
    interval: 500
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!status.running && !root.pending) status.running = true
  }
}
