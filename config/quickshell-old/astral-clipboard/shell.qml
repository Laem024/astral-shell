pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "settings" as Settings
import "design" as Design

ShellRoot {
  // qmllint disable incompatible-type
  Design.Theme { id: theme; settings: Settings.SettingsData }
  ClipboardService { id: clipboardService; settings: Settings.SettingsData }
  ClipboardPanel { settings: Settings.SettingsData; service: clipboardService; tokens: theme }
}
