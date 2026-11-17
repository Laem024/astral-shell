import QtQuick
import QtQuick.Window
import Quickshell
import "../common" as Common
import "Logic.js" as Logic

ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  // In-memory demo service: preview activation never reaches real launch tools.
  QtObject {
    id: demo
    property var entries: [
      {id:"browser", name:"Web Browser", icon:"web-browser"},
      {id:"files", name:"Files", icon:"system-file-manager"},
      {id:"terminal", name:"Terminal", icon:"utilities-terminal"},
      {id:"editor", name:"Text Editor", icon:"accessories-text-editor"},
      {id:"cafe", name:"Café Notes", icon:"accessories-notes"}
    ]
    property var state: Logic.emptyState()
    property string warning: "Preview: applications are simulated."
    property string error: ""
    property bool ready: true
    property bool pending: false
    function pin(entry) { state = Logic.toggle(state, Logic.identity(entry)); }
    function launch(entry) { state = Logic.record(state, Logic.identity(entry), Date.now()); error = "Simulated launch: " + entry.name; }
  }
  Window {
    visible: true; width: 620; height: 560; color: theme.surface
    title: "Astral Launcher Preview"
    onClosing: Qt.quit()
    LauncherContent { id: content; anchors.fill: parent; service: demo; tokens: theme; onCloseRequested: Qt.quit(); Component.onCompleted: reset() }
  }
}
