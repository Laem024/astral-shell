import QtQuick
import Quickshell
import "../common" as Common

ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  QtObject { id: preferences; readonly property var value: Common.SettingsData.value.overview }
  Overview { settings: preferences; tokens: theme }
}
