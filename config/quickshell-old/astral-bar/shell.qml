pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "settings" as Settings
import "design"
import "data"
import "."
import "panel" as Panel

ShellRoot {
  Panel.PanelState { id: globalNavigation }
  IpcHandler {
    target: "bar"
    function closePanels(): void { globalNavigation.close(); }
  }
  Process {
    id: dismissWallpaper
    command: ["astral-wallpaper", "close"]
  }
  Process {
    id: dismissLauncher
    command: ["astral-launcher", "close"]
  }
  Process {
    id: dismissClipboard
    command: ["astral-clipboard", "close"]
  }
  Process {
    id: dismissSession
    command: ["astral-session", "close"]
  }
  Process {
    id: dismissOverview
    command: ["astral-overview", "close"]
  }
  Process {
    id: dismissShortcuts
    command: ["astral-shortcuts", "close"]
  }
  Connections {
    target: globalNavigation
    function onDestinationChanged() { if (globalNavigation.destination) { dismissLauncher.running = true; dismissWallpaper.running = true; dismissClipboard.running = true; dismissSession.running = true; dismissOverview.running = true; dismissShortcuts.running = true; } }
    function onTrayChanged() { if (globalNavigation.tray) { dismissLauncher.running = true; dismissWallpaper.running = true; dismissClipboard.running = true; dismissSession.running = true; dismissOverview.running = true; dismissShortcuts.running = true; } }
    function onWindowMenuChanged() { if (globalNavigation.windowMenu) { dismissLauncher.running = true; dismissWallpaper.running = true; dismissClipboard.running = true; dismissSession.running = true; dismissOverview.running = true; dismissShortcuts.running = true; } }
  }
  Theme { id: theme; settings: Settings.SettingsData }
  Component.onCompleted: WeatherData.activate(false)
  NotificationSoundPolicy {
    active: NotificationData.dnd || SessionData.blocked
    nodes: AudioData.playback
  }
  Binding { target: NotificationData; property: "sessionBlocked"; value: SessionData.blocked }
  Panel.NotificationPopups { settings: Settings.SettingsData; tokens: theme }
  Variants {
    model: Quickshell.screens
    delegate: AstralBar { settings: Settings.SettingsData; tokens: theme; navigation: globalNavigation }
  }
}
