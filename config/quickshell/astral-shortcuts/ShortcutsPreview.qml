import "Logic.js" as Logic
import QtQuick
import QtQuick.Window
import Quickshell
import "../common" as Common

ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  QtObject {
    id: sample
    property bool loading: false
    property string error: ""
    readonly property var parsed: Logic.parseBinds(JSON.stringify([
      {enabled:true,modmask:64,key:"V",description:"Clipboard · Paste from history"},
      {enabled:true,modmask:64,key:"slash",description:"Astral · Keyboard shortcuts"},
      {enabled:true,modmask:8,key:"Tab",description:"Workspaces · Overview"}
    ]))
    property var categories: parsed.categories
    property int total: parsed.total
    function refresh() {}
  }
  Window {
    visible: true; width: 1180; height: 780; color: theme.surface; title: "Astral Shortcuts Preview"
    ShortcutsContent { anchors.fill: parent; tokens: theme; shortcuts: sample; active: true }
  }
}
