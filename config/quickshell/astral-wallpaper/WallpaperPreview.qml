import QtQuick
import QtQuick.Window
import Quickshell
import "../common" as Common

Scope {
  id: root
  readonly property var display: ({name: "Preview", x: 0, y: 0, width: 640, height: 360})
  Common.Theme { id: theme; settings: Common.SettingsData }
  WallpaperService { id: service; settings: Common.SettingsData; blocked: false; screens: [root.display] }
  Window {
    visible: true; width: 1100; height: 780; title: "Astral Wallpaper — isolated preview"
    onClosing: Qt.quit()
    WallpaperContent { anchors.fill: parent; service: service; tokens: theme; onCloseRequested: Qt.quit() }
  }
  Window {
    visible: true; width: 640; height: 360; title: "Wallpaper renderer preview"
    Rectangle { anchors.fill: parent; color: theme.background }
    WallpaperRenderer { anchors.fill: parent; service: service; modelData: root.display }
  }
}
