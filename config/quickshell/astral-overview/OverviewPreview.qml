import QtQuick
import QtQuick.Window
import Quickshell
import "../common" as Common

ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  QtObject {
    id: sample
    property int activeId: 1
    property int selectedIndex: 0
    property int blockStart: 0
    property int blockEnd: 4
    property int windowTotal: 0
    property var monitors: [{id:0,name:"Preview monitor",focused:true}]
    property var workspaces: [1,2,3,4].map(id => ({id:id,exists:true,current:id===1,monitorId:0,monitorName:"Preview monitor",windows:[]}))
    readonly property var selectedWorkspace: workspaces[selectedIndex]
    function selectRelative(delta) { selectedIndex = (selectedIndex+delta+4)%4; }
    function moveWindow(address, workspace) {}
  }
  Window {
    visible: true; width: 1180; height: 720; color: theme.background; title: "Astral Overview Preview"
    OverviewContent { anchors.fill: parent; tokens: theme; overview: sample; active: true; previews: false }
  }
}
