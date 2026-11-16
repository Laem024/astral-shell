pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design

ShellRoot {
  id: root
  property int ticks: 0
  property var first: null
  function check(ok, label) { if (!ok) { console.error("CAPTURE_PREFERENCES_FAIL " + label); Qt.exit(1); } }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
    return null;
  }
  QtObject { id: testSettings; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: testSettings }
  FloatingWindow { visible: true; implicitWidth: 400; implicitHeight: 700; Item { id: scene; anchors.fill: parent } }
  Component { id: factory; Panel.DisplayPage { tokens: theme; width: 400; height: 700 } }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      if (++root.ticks > 80) root.check(false, "timeout");
      if (Data.BrightnessData.monitors.length !== 2) return;
      root.check(Data.CapturePreferences.task === "record" && Data.CapturePreferences.source === "region" && Data.CapturePreferences.audio === "both" && Data.CapturePreferences.monitor === "DP-1", "preferences restored after restart");
      if (!root.first) {
        root.first = factory.createObject(scene);
        root.check(root.first.task === "record" && root.first.mode === "region" && root.first.audio === "both", "new page restores choices");
        root.first.destroy();
        root.first = factory.createObject(scene);
        root.check(root.first.task === "record" && root.first.mode === "region" && root.first.audio === "both", "reopened page restores choices");
        root.check(root.find(root.first, "captureMonitorSelector").currentText === "DP-1", "saved display selection");
        Data.CapturePreferences.selectSource("invalid");
        root.check(Data.CapturePreferences.source === "region", "invalid choice ignored");
      }
      console.log("CAPTURE_PREFERENCES_PASS"); Qt.quit();
    }
  }
}
