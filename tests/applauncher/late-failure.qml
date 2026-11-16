import QtQuick
import Quickshell
import "../../config/quickshell/astral-launcher" as Launcher
import "../../config/quickshell/common" as Common
Scope {
  id: root
  property bool started: false
  Common.Command { id: request }
  Launcher.LauncherService { id: service; settings: Common.SettingsData }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      if (!service.ready) return;
      if (!root.started) {
        root.started = true;
        const path = Common.Paths.state + "/astral-launcher";
        request.run(["mv", "--", path, path + ".previous"], code => {
          if (code !== 0) { Qt.exit(1); return; }
          request.run(["touch", "--", path], code => {
            if (code !== 0) { Qt.exit(1); return; }
            service.pin({id:"volatile"});
          });
        });
      } else if (service.warning.includes("Cannot save") && !service.dirty) {
        if (!service.state.favorites.includes("volatile.desktop")) { Qt.exit(1); return; }
        console.log("LAUNCHER_LATE_FAILURE_PASS"); Qt.quit();
      }
    }
  }
}
