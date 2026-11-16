import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

Scope {
  id: root
  required property var settings
  property var state: ({ dir: "", items: [] })
  readonly property var items: state.items
  readonly property string dir: state.dir
  property bool ready: false
  property bool watching: false
  property bool started: false
  property string error: ""
  property string warning: ""
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("state.sh").toString().replace(/^file:\/\//, ""))

  signal copied()
  signal copyFailed(string message)

  function reload() {
    if (!reader.running) reader.running = true;
  }
  function trim() {
    if (root.ready && !trimmer.running) trimmer.running = true;
  }
  function remove(id) {
    if (!root.ready || remover.running || typeof id !== "string") return;
    remover.command = ["bash", root.helper, "remove", id];
    remover.running = true;
  }
  function copy(item) {
    if (!root.ready || copier.running || !item || typeof item.id !== "string") return;
    root.error = "";
    copier.command = ["bash", root.helper, "copy", item.id];
    copier.running = true;
  }
  function source(item) {
    if (!item || item.kind !== "image" || !item.file || !root.dir) return "";
    const path = item.file.startsWith("/") ? item.file : root.dir + "/" + item.file;
    return "file://" + path.split("/").map((part, index) => index === 0 ? "" : encodeURIComponent(part)).join("/");
  }

  Process {
    id: reader
    command: ["bash", root.helper, "read"]
    running: true
    stdout: StdioCollector { id: readOutput }
    stderr: StdioCollector { id: readError }
    onExited: (code, status) => {
      if (code !== 0 || status !== 0) {
        root.warning = readError.text.trim() || "Clipboard history could not be read.";
        root.ready = true;
        return;
      }
      try {
        root.state = Logic.parseState(readOutput.text);
        root.warning = "";
      } catch (e) {
        root.warning = "Clipboard history is invalid and was ignored.";
      }
      root.ready = true;
      if (!root.started) {
        root.started = true;
        Qt.callLater(root.trim);
      }
    }
  }
  Process {
    id: trimmer
    command: ["bash", root.helper, "trim"]
    stderr: StdioCollector { id: trimError }
    onExited: (code, status) => {
      if (code !== 0 || status !== 0) root.warning = trimError.text.trim() || "Clipboard history could not be trimmed.";
      else root.reload();
    }
  }
  Process {
    id: remover
    stderr: StdioCollector { id: removeError }
    onExited: (code, status) => {
      if (code !== 0 || status !== 0) root.warning = removeError.text.trim() || "The clipboard entry could not be removed.";
      else root.reload();
    }
  }
  Process {
    id: copier
    stderr: StdioCollector { id: copyError }
    onExited: (code, status) => {
      if (code !== 0 || status !== 0) {
        root.error = copyError.text.trim() || "The selected entry could not be copied.";
        root.copyFailed(root.error);
      } else {
        root.error = "";
        root.copied();
      }
    }
  }
  Process {
    id: watcher
    command: ["bash", root.helper, "watch"]
    running: true
    stdout: StdioCollector {}
    stderr: StdioCollector { id: watchError }
    onStarted: {
      root.watching = true;
      root.warning = "";
    }
    onExited: (code, status) => {
      root.watching = false;
      if (code !== 0 || status !== 0) root.warning = watchError.text.trim() || "Clipboard watcher stopped. Install wl-clipboard.";
      restart.restart();
    }
  }
  Timer {
    id: restart
    interval: 5000
    onTriggered: if (!root.watching) watcher.running = true
  }
  Connections {
    target: root.settings
    function onValueChanged() { if (root.ready) root.trim(); }
  }
}
