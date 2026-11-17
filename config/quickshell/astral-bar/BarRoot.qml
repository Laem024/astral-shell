pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "settings" as Settings
import "../common" as Common
import "data"
import "." as Bar
import "panel" as Panel

ShellRoot {
  id: root
  property var bars: []
  Panel.PanelState { id: globalNavigation }
  IpcHandler {
    target: "bar"
    function closeActive(): string {
      if (Common.Privacy.blocked) return "blocked";
      if (!globalNavigation.owner) return "inactive";
      globalNavigation.close(); return "closed";
    }
    function openSettingsPage(page: string): string {
      if (Common.Privacy.blocked) return "blocked";
      const bar = root.bars.find(b => b.visible);
      if (!bar) return "unavailable";
      bar.openSettingsPage(page === "audio" ? "Sound" : "Control Center");
      return "ok";
    }
    function closePanels(): void { globalNavigation.close(); }
  }
  Common.Theme { id: theme; settings: Settings.SettingsData }
  Component.onCompleted: WeatherData.activate(false)
  NotificationSoundPolicy {
    active: NotificationData.dnd || SessionData.blocked
    nodes: AudioData.playback
  }
  Binding { target: NotificationData; property: "sessionBlocked"; value: SessionData.blocked }
  Panel.NotificationPopups { settings: Settings.SettingsData; tokens: theme }
  Variants {
    model: Quickshell.screens
    delegate: Bar.AstralBar {
      id: barInstance
      settings: Settings.SettingsData
      tokens: theme
      navigation: globalNavigation
      Component.onCompleted: root.bars = root.bars.concat([barInstance])
      Component.onDestruction: root.bars = root.bars.filter(b => b !== barInstance)
    }
  }
}
