import QtQuick
import Quickshell
import "../../config/quickshell/astral-launcher" as Launcher
import "../../config/quickshell/common" as Common
Scope {
  Launcher.LauncherService {
    id: service; settings: Common.SettingsData
    onReadyChanged: if (ready) {
      if (warning || !state.favorites.includes("native.desktop") || state.usage["terminal.desktop"].count !== 1) {
        console.error("LAUNCHER_FAIL persisted state"); Qt.exit(1); return;
      }
      console.log("LAUNCHER_PERSISTENCE_PASS"); Qt.quit();
    }
  }
}
