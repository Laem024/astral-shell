import QtQuick
import QtQuick.Window
import Quickshell
import "../common" as Common
import "Logic.js" as Logic

// No SessionService or power commands: this window displays the action tiles only.
ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  Window {
    width: 760; height: 520; visible: true
    title: "Astral Session Preview"
    color: theme.surface
    Column {
      anchors.fill: parent; anchors.margins: 24; spacing: 8
      Text { text: "Session preview — actions are disabled"; color: theme.text; font.pixelSize: 22 }
      Repeater {
        model: Logic.actions
        delegate: ActionTile {
          required property var modelData
          width: parent.width; height: 72
          tokens: theme; actionData: modelData; enabled: false
        }
      }
    }
  }
}
