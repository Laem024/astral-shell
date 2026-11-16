import QtQuick
import QtQuick.Window
import Quickshell
import "../common" as Common

ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  QtObject { id: preferences; property var value: Common.SettingsData.value.clipboard }
  QtObject {
    id: sample
    property string error: ""
    property string warning: "Preview data — clipboard actions are disabled"
    property bool watching: false
    property var items: [
      {id: "a".repeat(64),kind:"text",mime:"text/plain",text:"Welcome to Astral clipboard",time:Date.now()},
      {id: "b".repeat(64),kind:"text",mime:"text/plain",text:"Multiline text\nkeeps its formatting.",time:Date.now()-60000}
    ]
    function source(item) { return ""; }
  }
  Window {
    visible: true; width: 980; height: 680; color: theme.surface; title: "Astral Clipboard Preview"
    ClipboardContent { anchors.fill: parent; tokens: theme; settings: preferences; service: sample; active: true; mode: "paste" }
  }
}
