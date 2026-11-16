import QtQuick
import QtQuick.Window
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/common" as Settings
import "../../config/quickshell/common" as Design

Scope {
  QtObject { id: preferences; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: preferences }
  Wallpaper.WallpaperService { id: controller; settings: preferences; blocked: false; screens: [] }
  Window {
    visible: true; width: 1280; height: 800
    Wallpaper.WallpaperContent { id: content; anchors.fill: parent; service: controller; tokens: theme }
  }
  Component.onCompleted: {
    if (typeof Quickshell.inhibitReloadPopup === "function") Quickshell.inhibitReloadPopup();
    if (content.tab === "Local") {
      console.log("WALLPAPER_RELOAD_PASS");
      Qt.callLater(Qt.quit);
    } else console.log("WALLPAPER_RELOAD_READY");
  }
  Connections {
    target: Quickshell
    function onReloadCompleted() { Quickshell.inhibitReloadPopup(); }
    function onReloadFailed(errorString) { console.error("WALLPAPER_FAIL: " + errorString); Qt.exit(1); }
  }
}
