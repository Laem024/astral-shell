pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "settings" as Settings
import "design" as Design

ShellRoot {
  // qmllint disable incompatible-type
  Design.Theme { id: theme; settings: Settings.SettingsData }
  SessionMenu { settings: Settings.SettingsData; tokens: theme }
}
