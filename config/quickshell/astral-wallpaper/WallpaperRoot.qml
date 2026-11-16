import QtQuick
import Quickshell
import "../common" as Common

ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  WallpaperService { id: controller; settings: Common.SettingsData; blocked: Common.Privacy.blocked }
  WallpaperCarousel { id: carousel; service: controller; tokens: theme; onOpenedChanged: if (opened) selector.close() }
  WallpaperSelector { id: selector; service: controller; tokens: theme; onOpenedChanged: if (opened) carousel.close() }
  Variants { model: Quickshell.screens; delegate: WallpaperSurface { service: controller } }
}
