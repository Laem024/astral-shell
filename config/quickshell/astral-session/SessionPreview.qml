import QtQuick
import QtQuick.Window
import Quickshell
import "../common" as Common
import "Logic.js" as Logic

// No SessionService or power commands: this window displays the action tiles only.
ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  Window {
    width: 680; height: 520; visible: true
    title: "Astral Session Preview"
    color: theme.background
    Rectangle {
      anchors.centerIn: parent
      width: 640; height: 440
      radius: theme.panelRadius
      color: theme.surface
      border.color: theme.border
      Column {
        anchors.fill: parent; anchors.margins: 24; spacing: 8
        Text { text: "Session preview — actions are disabled"; color: theme.muted; font { family: theme.font; pixelSize: 12 } }
        Repeater {
          model: Logic.actions
          delegate: ActionTile {
            required property var modelData
            width: parent.width; height: 60
            tokens: theme; actionData: modelData; enabled: false
          }
        }
      }
    }
  }
}
