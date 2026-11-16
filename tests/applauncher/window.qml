import QtQuick
import Quickshell
import "../../config/quickshell/astral-launcher" as Launcher
import "../../config/quickshell/common" as Common
ShellRoot {
  id: root
  property int stage: 0
  function check(ok, message) { if (!ok) { console.error("LAUNCHER_WINDOW_FAIL " + message); Qt.quit(); } }
  QtObject { id: settings; property var value: Common.SettingsData.value }
  Common.Theme { id: theme; settings: settings }
  Launcher.AppLauncher { id: launcher; settings: settings; tokens: theme }
  Timer {
    interval: 300; repeat: true; running: true
    onTriggered: {
      if (!launcher.privacyReady) return;
      if (root.stage === 0) {
        launcher.toggle(Quickshell.screens[0]);
        root.check(launcher.opened, "open without bar");
      } else if (root.stage === 1) {
        root.check(launcher.opened, "window stays open after mapping");
        launcher.toggle(null);
        root.check(!launcher.opened, "repeat toggle closes");
        launcher.toggle(null);
        Common.Privacy.blocked = true;
        root.check(!launcher.opened, "lock closes launcher");
        launcher.toggle(null);
        root.check(!launcher.opened, "lock prevents opening");
        Common.Privacy.blocked = false;
        settings.value.mode = "light"; settings.value.scale = 1.5;
        launcher.toggle(null);
      } else if (root.stage === 2) {
        root.check(launcher.opened, "light scaled window");
        root.check(launcher.closeActive() === "closed" && launcher.closeActive() === "closed", "close consumed during animation");
      } else if (root.stage === 3) {
        root.check(launcher.closeActive() === "inactive", "inactive after animation");
        launcher.toggle(null);
        launcher.screens = [];
        root.check(!launcher.opened, "monitor disappearance closes launcher");
      } else {
        console.log("LAUNCHER_WINDOW_PASS"); Qt.quit();
      }
      root.stage++;
    }
  }
}
