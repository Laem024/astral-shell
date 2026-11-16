import QtQuick
import Quickshell
import Quickshell.Io
import "../common" as Common

Scope {
  id: root
  readonly property string directory: Common.Paths.state + "/astral-launcher"
  property bool ready: false
  property bool writable: false
  property bool writing: false
  property string pending: ""
  signal loaded(string contents)
  signal failure(string detail)
  Common.Command { id: setup }
  FileView {
    id: file
    path: root.writable ? root.directory + "/state.json" : ""
    atomicWrites: true; blockWrites: true; blockLoading: true; printErrors: false
    onLoadFailed: root.failure("State could not be loaded. Favorites and history start empty for this session.")
    onSaved: { root.writing = false; Qt.callLater(root.flush); }
    onSaveFailed: { root.writing = false; root.failure("Cannot save favorites and history. Changes remain available for this session."); }
  }
  function save(text) {
    if (!writable) { failure("Cannot save favorites and history. Changes remain available for this session."); return; }
    pending = text; flush();
  }
  function flush() {
    if (!ready || writing || !pending) return;
    const text = pending; pending = "";
    if (file.text() === text) return;
    writing = true; file.setText(text);
  }
  function failed() {
    failure("Cannot save favorites and history. State storage is unavailable; changes remain available for this session.");
    ready = true; loaded("");
  }
  function read() { writable = true; const text = file.text(); ready = true; loaded(text); }
  Component.onCompleted: {
    const dirs = [Common.Paths.state, directory];
    setup.run(["mkdir", "-p", "-m", "700", "--"].concat(dirs), code => {
      if (code !== 0) { failed(); return; }
      setup.run(["chmod", "700", "--"].concat(dirs), code => {
        if (code !== 0) { failed(); return; }
        const path = directory + "/state.json";
        setup.run(["test", "-e", path], code => {
          setup.run(code === 0 ? ["chmod", "600", "--", path] : ["install", "-m", "600", "/dev/null", path], code => {
            if (code !== 0) failed(); else read();
          });
        });
      });
    });
  }
}
