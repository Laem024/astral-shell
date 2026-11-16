import QtQuick
import Quickshell.Io

// A single argument-vector transaction, including failed-start and deadline paths.
QtObject {
  id: root
  property var callback: null
  property bool pending: false
  readonly property bool running: pending
  property int timeout: 20000
  property bool timedOut: false
  function run(args, done): void {
    if (pending) { if (done) done(1, "", "Operation already running."); return; }
    callback = done; pending = true; timedOut = false;
    process.command = args;
    process.running = true;
    deadline.restart();
  }
  function complete(code, text, error) {
    if (!pending) return;
    deadline.stop();
    const done = callback, expired = timedOut;
    callback = null; pending = false;
    Qt.callLater(() => { if (done) done(expired ? 124 : code, text, expired ? "Operation timed out." : error); });
  }
  property Timer deadline: Timer {
    interval: root.timeout
    onTriggered: {
      root.timedOut = true;
      if (process.running) process.signal(9);
      else root.complete(124, "", "Operation timed out.");
    }
  }
  property Process process: Process {
    environment: ({LC_ALL: "C.UTF-8"})
    stdout: StdioCollector { id: output }
    stderr: StdioCollector { id: errors }
    onExited: (code, status) => root.complete(status === 0 ? code : 1, output.text, errors.text)
    onRunningChanged: if (!running && root.pending) Qt.callLater(() => {
      if (!process.running && root.pending) root.complete(127, "", "Could not start " + process.command[0] + ".");
    })
  }
}
