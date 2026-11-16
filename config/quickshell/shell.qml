pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import "common" as Common
import "common/ModuleLogic.js" as Modules

ShellRoot {
  id: root
  readonly property var registry: Common.SettingsData.value.modules
  property bool ready: false
  ListModel { id: activeModules }
  function reconcile() {
    if (!ready) return;
    const entries = Modules.entries(registry, Quickshell.shellDir);
    for (let index = activeModules.count - 1; index >= 0; index--) {
      const current = activeModules.get(index);
      if (!entries.some(row => row.identifier === current.identifier && row.entry === current.entry)) activeModules.remove(index);
    }
    for (const row of entries) {
      let found = false;
      for (let index = 0; index < activeModules.count; index++) if (activeModules.get(index).identifier === row.identifier) found = true;
      if (!found) activeModules.append(row);
    }
  }
  Component.onCompleted: { ready = true; reconcile(); }
  onRegistryChanged: reconcile()
  // Each module owns a separate qs instance. Removing a delegate stops only
  // the child it started. qs handles duplicates against preexisting instances.
  Instantiator {
    model: activeModules
    delegate: Process {
      id: moduleProcess
      required property string identifier
      required property string entry
      command: ["qs", "--no-duplicate", "-p", entry]
      running: true
      stdout: SplitParser { onRead: line => console.log("[" + moduleProcess.identifier + "] " + line) }
      stderr: SplitParser { onRead: line => console.warn("[" + moduleProcess.identifier + "] " + line) }
      onExited: (code, status) => { if (code !== 0 || status !== 0) console.error("Module failed: " + identifier); }
    }
  }
}
