import QtQuick
import Quickshell
import Quickshell.Io

// flock only holds a file descriptor; all startup decisions stay in JavaScript.
Scope {
  id: root
  required property string key
  property bool releasing: false
  signal acquired()
  signal failed(string message)
  readonly property string path: Paths.runtime + "/" + key + ".lock"
  Command { id: prepare }
  function acquire() {
    releasing = false;
    holder.stdinEnabled = true;
    if (!Quickshell.env("XDG_RUNTIME_DIR").startsWith("/")) { failed("XDG_RUNTIME_DIR is required."); return; }
    prepare.run(["mkdir", "-p", "-m", "700", "--", Paths.runtime], code => {
      if (code !== 0) { failed("Cannot prepare runtime storage."); return; }
      prepare.run(["chmod", "700", "--", Paths.runtime], code => {
        if (code !== 0) { failed("Cannot secure runtime storage."); return; }
        prepare.run(["touch", "--", path], code => {
          if (code !== 0) { failed("Cannot prepare startup lock."); return; }
          prepare.run(["chmod", "600", "--", path], code => {
            if (code !== 0) { failed("Cannot secure startup lock."); return; }
            holder.running = true;
          });
        });
      });
    });
  }
  function release() { releasing = true; holder.stdinEnabled = false; }
  Process {
    id: holder
    command: ["flock", "--exclusive", "--timeout", "20", root.path, "tee"]
    stdinEnabled: true
    onStarted: write("acquired\n")
    stdout: SplitParser { onRead: line => { if (line === "acquired") root.acquired(); } }
    stderr: StdioCollector {}
    onExited: if (!root.releasing) root.failed("Could not acquire startup lock.")
    onRunningChanged: if (!running && !root.releasing) Qt.callLater(() => {
      if (!holder.running && !root.releasing) root.failed("Could not start startup lock.");
    })
  }
}
