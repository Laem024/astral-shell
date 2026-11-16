pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "settings" as Settings
import "design" as Design
import "data" as Data

ShellRoot {
  // qmllint disable incompatible-type
  Design.Theme { id: theme; settings: Settings.SettingsData }
  WallpaperService { id: controller; settings: Settings.SettingsData; blocked: Data.SessionData.blocked }
  WallpaperCarousel {
    id: carousel; service: controller; tokens: theme
    onOpenedChanged: if (opened) selector.close()
  }
  WallpaperSelector {
    id: selector; service: controller; tokens: theme
    onOpenedChanged: if (opened) carousel.close()
  }
  Variants {
    model: Quickshell.screens
    delegate: WallpaperSurface { service: controller }
  }
}
