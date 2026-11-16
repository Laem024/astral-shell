import QtQuick
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/common" as Settings

Scope {
  QtObject { id: preferences; property var value: Settings.SettingsData.value }
  Wallpaper.WallpaperService { id: controller; settings: preferences; screens: []; blocked: false }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      if (!controller.ready || controller.scanning) return;
      const s = controller.state;
      if (controller.warning || s.layout !== "Per monitor" || !s.selections.light.monitors.A.endsWith("light.png") || !s.selections.dark.monitors.B || s.rotation || s.random) {
        console.error("WALLPAPER_FAIL: preferences and assignments did not survive restart"); Qt.exit(1);
      }
      console.log("WALLPAPER_RESTORE_PASS (fresh service reads saved preferences and both themes)"); Qt.quit();
    }
  }
}
