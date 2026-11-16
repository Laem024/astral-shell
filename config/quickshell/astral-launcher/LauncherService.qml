import QtQuick
import Quickshell
import "../common" as Common
import "Logic.js" as Logic

Scope {
  id: root
  required property var settings
  property var entries: DesktopEntries.applications.values
  property var state: Logic.emptyState()
  property string warning: ""
  property string error: ""
  property bool ready: false
  readonly property bool dirty: storage.writing || storage.pending !== ""
  property bool pending: false
  signal accepted()
  function save() { storage.save(JSON.stringify(state) + "\n"); }
  function pin(entry) {
    if (!ready) return;
    state = Logic.toggle(state, Logic.identity(entry)); save();
  }
  function launch(entry) {
    if (pending || !ready) return;
    error = "";
    try {
      const command = Logic.launchCommand(entry, settings.value.applications.terminal);
      const id = Logic.identity(entry);
      pending = true;
      application.launch(command, entry.runInTerminal ? entry.workingDirectory || "" : "", (ok, detail) => {
        pending = false;
        if (!ok) { error = detail; return; }
        state = Logic.record(state, id, Date.now()); save(); accepted();
      });
    } catch (e) { pending = false; error = String(e); }
  }
  Common.ApplicationLaunch { id: application }
  StateStore {
    id: storage
    onFailure: detail => root.warning = detail
    onLoaded: contents => {
      try { if (contents.trim()) root.state = Logic.parseState(contents); }
      catch (e) { root.warning = "State could not be loaded. Favorites and history start empty for this session."; }
      root.ready = true;
    }
  }
}
