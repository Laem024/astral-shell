import QtQuick
import Quickshell
import "../common" as Common

ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  QtObject { id: preferences; readonly property var value: Common.SettingsData.value.clipboard }
  ClipboardService { id: clipboard; settings: preferences }
  ClipboardPanel { settings: preferences; tokens: theme; service: clipboard }
}
