import QtQuick
import Quickshell
import "../../config/quickshell/astral-launcher" as Launcher
import "../../config/quickshell/common" as Common
Scope {
  id: root
  property bool pinned: false
  QtObject { id: settings; property var value: Common.SettingsData.value }
  Launcher.LauncherService { id: service; settings: settings }
  Timer {
    running: true; repeat: true; interval: 100
    onTriggered: {
      if (!service.ready) return;
      if (!root.pinned) { service.pin({id:"test",name:"Test"}); root.pinned = true; }
      else if (service.warning.includes("Cannot save")) {
        if (!service.state.favorites.includes("test.desktop")) { console.error("LAUNCHER_FAIL volatile favorites"); Qt.quit(); }
        console.log("LAUNCHER_WRITE_PASS"); Qt.quit();
      }
    }
  }
}
