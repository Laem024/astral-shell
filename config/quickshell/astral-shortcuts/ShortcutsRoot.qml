import QtQuick
import Quickshell
import "../common" as Common

ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  ShortcutsMenu { settings: Common.SettingsData; tokens: theme }
}
