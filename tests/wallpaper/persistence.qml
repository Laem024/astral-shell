import QtQuick
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/common" as Common

Scope {
  Wallpaper.WallpaperService { id: service; settings: Common.SettingsData; screens: []; blocked: false }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      if (!service.ready || service.scanning || service.dirty) return;
      if (service.state.minutes !== 42 || service.state.fade !== 33 || service.state.random || service.warning) { console.error("WALLPAPER_FAIL: fresh process did not restore state"); Qt.exit(1); }
      console.log("WALLPAPER_PERSISTENCE_PASS"); Qt.quit();
    }
  }
}
