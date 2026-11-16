pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  // A persistent runtime marker survives a failed locker and a bar restart.
  property bool ready: false
  property bool blocked: true
  readonly property string helper: "astral-lock"
  property string confirmation: ""
  property string error: ""
  property bool pending: false
  function lock(): void { perform("lock"); }
  function ask(action: string): void {
    if (pending) return;
    if (action === "lock" || action === "suspend") perform(action);
    else if (["logout", "reboot", "poweroff"].includes(action)) { error = ""; confirmation = action; }
  }
  function cancel(): void { confirmation = ""; }
  function confirm(): void {
    const action = confirmation;
    confirmation = "";
    if (["logout", "reboot", "poweroff"].includes(action)) perform(action);
  }
  function perform(action: string): void {
    if (pending || !["lock", "suspend", "logout", "reboot", "poweroff"].includes(action)) return;
    error = "";
    pending = true;
    if (action === "lock" || action === "suspend") blocked = true;
    request.command = [helper, action];
    request.running = true;
  }
  Process {
    id: request
    stderr: StdioCollector { id: requestError }
    onExited: (code, status) => {
      root.pending = false;
      if (code !== 0 || status !== 0) root.error = requestError.text.trim() || "Could not complete the session action.";
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
  Timer { interval: 500; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!status.running && !root.pending) status.running = true }
}
