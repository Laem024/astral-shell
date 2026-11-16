import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

Scope {
  id: root
  required property var settings
  property var entries: DesktopEntries.applications.values
  property var state: Logic.emptyState()
  property string warning: ""
  property string error: ""
  property bool ready: false
  property bool dirty: false
  property bool pending: false
  property string requestedId: ""
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("state.sh").toString().replace(/^file:\/\//, ""))
  signal accepted()
  function save() {
    dirty = true;
    if (ready && !writer.running) {
      dirty = false;
      writer.running = true;
    }
  }
  function pin(entry) {
    if (!ready) return;
    state = Logic.toggle(state, Logic.identity(entry)); save();
  }
  function launch(entry) {
    if (pending || !ready) return;
    error = "";
    try {
      let command = Logic.launchCommand(entry, settings.value.applications.terminal);
      if (!entry.runInTerminal) command = ["bash", decodeURIComponent(Qt.resolvedUrl("launch-desktop.sh").toString().replace(/^file:\/\//, ""))].concat(command);
      if (entry.runInTerminal) command = ["bash", decodeURIComponent(Qt.resolvedUrl("launch-terminal.sh").toString().replace(/^file:\/\//, "")), entry.workingDirectory].concat(command);
      requestedId = Logic.identity(entry);
      request.command = command;
      pending = true;
      request.running = true;
    } catch (e) { error = String(e); }
  }
  Process {
    id: reader
    command: ["bash", root.helper, "read"]
    running: true
    stdout: StdioCollector { id: contents }
    onExited: (code, status) => {
      try {
        if (code !== 0 || status !== 0) throw new Error("Cannot read launcher state");
        root.state = Logic.parseState(contents.text);
      } catch (e) { root.warning = "State could not be loaded. Favorites and history start empty for this session."; }
      root.ready = true;
    }
  }
  Process {
    id: writer
    command: ["bash", root.helper, "write"]
    stdinEnabled: true
    onStarted: { write(JSON.stringify(root.state)); stdinEnabled = false; }
    onExited: (code, status) => {
      if (code !== 0 || status !== 0) root.warning = "Cannot save favorites and history. Changes remain available for this session.";
      stdinEnabled = true;
      if (root.dirty) Qt.callLater(root.save);
    }
  }
  Process {
    id: request
    stderr: StdioCollector { id: failure }
    onExited: (code, status) => {
      root.pending = false;
      if (code === 0 && status === 0) {
        root.state = Logic.record(root.state, root.requestedId, Date.now());
        root.save(); root.accepted();
      } else root.error = failure.text.trim() || "Application launch request failed.";
    }
  }
}
