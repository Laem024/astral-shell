import QtQuick
import QtQuick.Window
import Quickshell
import "../common" as Common
import "Logic.js" as Logic

// No SessionService or power commands: this window displays the action tiles only.
ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  Window {
    width: 868; height: 398; visible: true
    title: "Astral Session Preview"
    color: theme.background
    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 48; height: parent.height - 48
      radius: theme.panelRadius
      color: theme.surface
      border.color: theme.border
      Column {
        anchors.fill: parent; anchors.margins: 24; spacing: 8
        Text { text: "Session preview — actions are disabled"; color: theme.muted; font { family: theme.font; pixelSize: 12 } }
        Flickable {
          width: parent.width; height: parent.height - 32
          contentWidth: width
          contentHeight: previewGrid.height
          clip: true
          Grid {
            id: previewGrid
            width: parent.width
            columns: width >= 652 ? 5 : width >= 372 ? 3 : 2
            spacing: 10
            Repeater {
              model: ["lock", "logout", "suspend", "reboot", "poweroff"].map(id => Logic.byId(id))
              delegate: ActionTile {
                required property var modelData
                width: (previewGrid.width - (previewGrid.columns - 1) * previewGrid.spacing) / previewGrid.columns
                height: 172
                tokens: theme
                actionData: modelData
                enabled: false
              }
            }
          }
        }
      }
    }
  }
}
