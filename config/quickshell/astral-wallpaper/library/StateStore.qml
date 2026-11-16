import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common

Scope {
  id: root
  readonly property string directory: Common.Paths.state + "/astral-wallpaper"
  readonly property string cache: Common.Paths.cache + "/astral-wallpaper"
  property bool ready: false
  property bool writing: false
  property string pending: ""
  property string key: ""
  property bool keyBusy: false
  signal loaded(string contents)
  signal failure(string detail)
  signal flushed()
  Common.Command { id: setup }
  FileView { id: stateFile; path: root.ready ? root.directory + "/state.json" : ""; printErrors: false; blockLoading: true; atomicWrites: true
    onSaved: { root.writing = false; root.flushed(); Qt.callLater(root.flush); }
    onSaveFailed: { root.writing = false; root.failure("Could not save wallpaper preferences."); }
  }
  FileView { id: keyFile; path: root.directory + "/api-key"; printErrors: false; blockLoading: true; blockWrites: true; atomicWrites: true }
  function ensureFile(path, done) {
    setup.run(["test", "-e", path], code => {
      if (code === 0) setup.run(["chmod", "600", "--", path], done);
      else setup.run(["install", "-m", "600", "/dev/null", path], done);
    });
  }
  function save(text) { pending = text; flush(); }
  function flush() {
    if (!ready || writing || !pending) return;
    const text = pending; pending = "";
    // FileView emits no saved signal when the requested contents are unchanged.
    if (stateFile.text() === text) { flushed(); return; }
    writing = true;
    stateFile.setText(text);
  }
  function setKey(value) {
    if (!ready || keyBusy || !/^[a-zA-Z0-9]*$/.test(value)) return false;
    keyBusy = true;
    keyFile.setText(value); keyFile.waitForJob();
    keyFile.reload(); key = keyFile.text().trim(); keyBusy = false;
    if (key !== value) { failure("Could not save the API key."); return false; }
    return true;
  }
  Component.onCompleted: {
    const directories = [Common.Paths.state, directory, Common.Paths.cache, cache];
    setup.run(["mkdir", "-p", "-m", "700", "--"].concat(directories), code => {
      if (code !== 0) { failure("Cannot create wallpaper storage."); return; }
      setup.run(["chmod", "700", "--"].concat(directories), code => {
        if (code !== 0) { failure("Cannot secure wallpaper storage."); return; }
        ensureFile(directory + "/state.json", code => {
          if (code !== 0) { failure("Cannot prepare wallpaper state."); return; }
          ensureFile(directory + "/api-key", code => {
            if (code !== 0) { failure("Cannot prepare API key storage."); return; }
            ready = true;
            keyFile.reload(); keyFile.waitForJob();
            key = keyFile.text().trim();
            if (!/^[a-zA-Z0-9]*$/.test(key)) { key = ""; failure("The saved API key is invalid."); }
            loaded(stateFile.text()); flush();
          });
        });
      });
    });
  }
}
