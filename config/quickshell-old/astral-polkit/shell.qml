import QtQuick
import Quickshell
import "settings" as Settings
import "design" as Design

ShellRoot {
  // qmllint disable incompatible-type
  Design.Theme { id: theme; settings: Settings.SettingsData }
  PolkitService { id: polkitService }
  PolkitDialog {
    settings: Settings.SettingsData
    service: polkitService
    tokens: theme
  }
}
