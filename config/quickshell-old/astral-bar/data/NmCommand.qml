import QtQuick
import Quickshell.Io

// One bounded command. Never retain or collect secret-bearing stdin/output.
Item {
  id: root
  property var completion: null
  property string input: ""
  property bool sensitive: false
  property bool active: false
  property int timeoutMs: 30000
  function run(args, callback, secret = "") {
    completion = callback;
    input = secret;
    sensitive = secret !== "";
    active = true;
    process.stdinEnabled = sensitive;
    process.command = ["env", "LC_ALL=C", "nmcli", "--colors", "no", "--terse", "--escape", "yes", "--wait", "25"].concat(args);
    process.running = true;
    deadline.restart();
  }
  function finish(code) {
    if (!active) return;
    active = false;
    deadline.stop();
    input = "";
    const callback = completion;
    const result = sensitive ? "" : output.text;
    completion = null;
    Qt.callLater(() => { if (callback) callback(code, result); });
  }
  Timer {
    id: deadline
    interval: root.timeoutMs
    onTriggered: {
      root.input = "";
      if (process.running) process.signal(9);
      else root.finish(124);
    }
  }
  StdioCollector { id: output; waitForEnd: true }
  SplitParser { id: discard; onRead: {} }
  Process {
    id: process
    stdout: root.sensitive ? discard : output
    stderr: SplitParser { onRead: {} }
    // Discard stderr: errors can echo user-supplied credentials.
    onStarted: {
      if (root.input) process.write(root.input);
      root.input = "";
      process.stdinEnabled = false;
    }
    onExited: (code, status) => root.finish(status === 0 ? code : 124)
  }
}
