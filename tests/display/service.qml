import QtQuick
import QtTest as Input
import Quickshell
import "../../config/quickshell/astral-bar" as Bar
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design

ShellRoot {
  id: root
  property int step: 0
  property var nativeLauncher: null
  property string opened: ""
  property int ticks: 0
  property int recordingDuration: 0
  property int geometryIndex: 0
  property int stateIndex: 0
  property var baseline: []
  property point instrumentBaseline: Qt.point(0, 0)
  readonly property var geometries: [
    [1920, 64, false], [1600, 64, false], [1280, 64, false], [1100, 64, false], [850, 64, false],
    [80, 1200, true], [80, 780, true], [80, 600, true]
  ]
  readonly property var captureStates: ["selecting", "preparing", "recording", "finalizing", "idle"]
  function geometry(): var {
    return ["composition", "endGroup", "workspaces", "music", "tray", "network", "audio", "battery", "recordingIndicator", "notifications"].map(name => {
      const item = find(bar, name);
      const point = item.mapToItem(bar, 0, 0);
      return [point.x, point.y, item.width, item.height];
    });
  }
  function sizeBar(): void {
    const size = geometries[geometryIndex];
    bar.width = size[0]; bar.height = size[1]; bar.vertical = size[2];
  }
  function check(ok, label) { if (!ok) { console.error("DISPLAY_FAIL " + label); Qt.exit(1); } }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
    return null;
  }
  Input.TestEvent { id: mouse }
  Panel.PanelState { id: navigation }
  FloatingWindow {
    visible: true
    implicitWidth: 1920; implicitHeight: 64
    Bar.BarContent { id: bar; settings: settings; tokens: theme; navigation: navigation; width: 1920; height: 64 }
  }
  QtObject { id: settings; property var value: Settings.SettingsData.value; Component.onCompleted: value = Object.assign({}, value, {animations: false}) }
  Design.Theme { id: theme; settings: settings }
  FloatingWindow {
    visible: true
    implicitWidth: 400; implicitHeight: 650
    color: theme.surface
    Panel.DisplayPage { id: displayPage; tokens: theme; anchors.fill: parent; anchors.margins: 12 }
  }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      if (++root.ticks > 200) root.check(false, "timeout step " + root.step);
      if (root.step === 0) {
        if (Data.BrightnessData.monitors.length !== 2) return;
        root.check(Data.CaptureData.audio === "none", "silent default");
        root.check(Data.NotificationData.applications.fileManager[0] === "thunar" && Data.NotificationData.applications.videoPlayer[0] === "vlc", "project application defaults");
        root.check(root.find(displayPage, "takeScreenshot").enabled, "screenshot action available");
        root.find(displayPage, "captureSource-window").clicked();
        root.check(displayPage.mode === "window" && !root.find(displayPage, "captureMonitorSelector").visible, "window source hides monitor selector");
        root.find(displayPage, "captureTask-record").clicked();
        root.check(displayPage.mode === "monitor" && !root.find(displayPage, "captureSource-window"), "video excludes window and falls back to monitor");
        Data.CapturePreferences.selectSource("window");
        root.check(displayPage.mode === "monitor", "video rejects window preference");
        root.check(!Data.CaptureData.prepare("record", "window", "", "none") && !Data.CaptureData.busy, "service rejects window recording");
        root.find(displayPage, "captureTask-shot").clicked();
        root.check(displayPage.mode === "window" && root.find(displayPage, "captureSource-window"), "screenshot window preference preserved");
        root.find(displayPage, "captureSource-region").clicked();
        root.check(displayPage.mode === "region", "region source selection");
        root.find(displayPage, "captureSource-monitor").clicked();
        root.find(displayPage, "captureTask-record").clicked();
        root.find(displayPage, "captureAudio-both").clicked();
        root.check(displayPage.audio === "both", "audio option selection");
        root.find(displayPage, "captureAudio-none").clicked();
        root.check(root.find(displayPage, "startRecording").text === "Start recording", "English recording action");
        const shortcut = root.find(bar, "recordingIndicator");
        root.check(shortcut.visible && !shortcut.recording, "idle capture shortcut");
        root.check(mouse.mouseClick(shortcut, shortcut.width / 2, shortcut.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "capture shortcut receives mouse click");
        root.check(!root.find(shortcut, "captureKeyboardFocus").visible, "mouse click has no focus frame");
        root.check(navigation.destination === "Display", "shortcut opens capture tab");
        navigation.close();
        Data.BrightnessData.setBrightness("eDP-1", 10);
        Data.BrightnessData.setBrightness("eDP-1", 30);
        Data.BrightnessData.setBrightness("DP-1", 80);
        root.check(Data.CaptureData.prepare("record", "monitor", "eDP-1", "none"), "prepare");
        root.check(!Data.CaptureData.prepare("shot", "monitor", "eDP-1", "none"), "double start");
        root.check(Data.CaptureData.duration === 0 && Data.CaptureData.startedAt === 0, "new capture resets the clock");
        root.check(Data.CaptureData.state === "hiding", "wait for hidden panel");
        Data.CaptureData.panelHidden(); root.step++;
      } else if (root.step === 1) {
        if (Data.CaptureData.state !== "recording") return;
        root.check(Data.CaptureData.busy, "persistent recording");
        root.check(Data.CaptureData.duration >= 2, "duration includes recorder startup before its readiness event");
        if (Data.CaptureData.duration < 3) return;
        root.recordingDuration = Data.CaptureData.duration;
        root.check(root.find(bar, "captureElapsed").text === "00:03", "visible timer advances in seconds");
        root.check(root.find(displayPage, "brightnessFeedback-eDP-1").text === "", "brightness updates do not add loading text");
        root.check(!root.find(displayPage, "captureSource-region").enabled && !root.find(displayPage, "captureAudio-system").enabled, "source and audio locked during recording");
        root.check(root.find(displayPage, "stopCapture").visible, "stop action replaces start actions");
        const indicator = root.find(bar, "recordingIndicator");
        root.check(indicator && indicator.visible, "bar indicator persists");
        indicator.clicked(); root.step++;
      } else if (root.step === 2) {
        if (Data.CaptureData.busy) return;
        root.check(Data.CaptureData.duration === root.recordingDuration, "timer freezes during finalization");
        root.check(Data.CaptureData.resultFile === "/tmp/result.mkv", "saved after finalization");
        root.check(Data.NotificationData.entries.length === 1 && Data.NotificationData.popups.length === 1, "local notification");
        const entry = Data.NotificationData.entries[0];
        root.check(Data.NotificationData.canOpen(entry) && entry.actions.length === 2, "history retains actions");
        root.nativeLauncher = Data.NotificationData.launchUrl;
        Data.NotificationData.launchUrl = function(url, id) { root.opened = url; Data.NotificationData.finishLaunch(id, true, ""); return true; };
        Data.NotificationData.invoke(entry.id, "folder");
        root.check(Data.NotificationData.find(entry.id).launchState === "opening", "immediate opening feedback");
        root.check(Data.NotificationData.popups.length === 0, "action dismisses popup immediately");
        Data.NotificationData.invoke(entry.id, "default");
        root.step = 20;
      } else if (root.step === 20) {
        root.check(root.opened === "file:///tmp", "open folder from history");
        const entry = Data.NotificationData.entries[0];
        root.check(entry.launchState === "idle" && !entry.launchMessage, "accepted launch leaves no sticky feedback");
        Data.NotificationData.invoke(entry.id, "default");
        root.step = 21;
      } else if (root.step === 21) {
        root.check(root.opened === "file:///tmp/result.mkv", "open file from history");
        const entry = Data.NotificationData.entries[0];
        Data.NotificationData.finishLaunch(entry.id, false, "No video app configured");
        root.check(Data.NotificationData.find(entry.id).launchState === "error", "launch failure stays actionable");
        Data.NotificationData.launchUrl = root.nativeLauncher;
        Data.NotificationData.invoke(entry.id, "default");
        root.step = 22;
      } else if (root.step === 22) {
        const entry = Data.NotificationData.entries[0];
        if (entry.launchState === "opening") return;
        root.check(entry.launchState === "error" && entry.launchMessage.indexOf("No video app configured") >= 0, "async opener reports real process failure");
        Data.NotificationData.dnd = true;
        Data.NotificationData.localFile("Quiet capture", "/tmp/result.png");
        root.check(Data.NotificationData.popups.length === 0 && Data.NotificationData.entries.length === 2, "DND stores history");
        Data.NotificationData.sessionBlocked = true;
        Data.NotificationData.dnd = false;
        Data.NotificationData.localFile("Blocked capture", "/tmp/blocked.png");
        root.check(Data.NotificationData.popups.length === 0, "lock suppresses popup");
        root.check(Data.CaptureData.prepare("record", "monitor", "eDP-1", "none"), "restart");
        Data.CaptureData.panelHidden(); root.step = 3;
      } else if (root.step === 3) {
        if (Data.CaptureData.state !== "recording") return;
        Data.SessionData.blocked = true; root.step++;
      } else if (root.step === 4) {
        if (Data.CaptureData.busy || Data.BrightnessData.pending) return;
        root.check(!Data.CaptureData.prepare("shot", "monitor", "eDP-1", "none"), "blocked start denied");
        root.sizeBar(); root.step++;
      } else if (root.step === 5) {
        root.baseline = root.geometry();
        const shortcut = root.find(bar, "recordingIndicator");
        root.check(shortcut.implicitHeight === (bar.vertical ? 38 : 40), "compact capture slot in both orientations");
        root.check(root.find(shortcut, "captureGlyph").scale === 1, "capture glyph uses full size in both orientations");
        const icon = root.find(root.find(bar, "recordingIndicator"), "captureInstrument");
        root.instrumentBaseline = icon.mapToItem(bar, icon.width / 2, icon.height / 2);
        Data.CaptureData.state = root.captureStates[root.stateIndex];
        Data.CaptureData.duration = 360000;
        root.step++;
      } else if (root.step === 6) {
        const actual = root.geometry();
        const icon = root.find(root.find(bar, "recordingIndicator"), "captureInstrument");
        const center = icon.mapToItem(bar, icon.width / 2, icon.height / 2);
        const shortcut = root.find(bar, "recordingIndicator");
        const content = root.find(shortcut, "captureContent");
        const contentCenter = content.mapToItem(shortcut, content.width / 2, content.height / 2);
        root.check(Math.abs(contentCenter.x - shortcut.width / 2) < 0.01 && Math.abs(contentCenter.y - shortcut.height / 2) < 0.01, "button and timer are centered together in every orientation: " + root.geometryIndex + " " + Data.CaptureData.state + " center=" + contentCenter + " slot=" + shortcut.width + "x" + shortcut.height);
        root.check(Math.abs(center.x - root.instrumentBaseline.x) < 0.5, "capture glyph stays horizontally aligned in every state");
        const elapsed = root.find(root.find(bar, "recordingIndicator"), "captureElapsed");
        root.check(elapsed.text === "6000:00", "long recording retains minutes and seconds");
        root.check(!elapsed.visible || !elapsed.truncated, "recording duration fits shortcut");
        root.check(actual.every((box, i) => box.every((value, j) => Math.abs(value - root.baseline[i][j]) < 0.5)),
          "stable bar geometry " + root.geometryIndex + " " + Data.CaptureData.state);
        if (++root.stateIndex < root.captureStates.length) {
          Data.CaptureData.state = root.captureStates[root.stateIndex];
          return;
        }
        root.stateIndex = 0;
        if (++root.geometryIndex < root.geometries.length) { root.sizeBar(); root.step = 5; return; }
        const video = Data.CaptureData.lastVideo;
        Data.CaptureData.kind = "shot";
        Data.CaptureData.saved("/tmp/last-shot.png");
        Data.CapturePreferences.selectTask("shot");
        root.check(displayPage.lastResult === "/tmp/last-shot.png", "screenshot result stays in screenshots");
        Data.CapturePreferences.selectTask("record");
        root.check(displayPage.lastResult === video && Data.CaptureData.lastScreenshot === "/tmp/last-shot.png", "video result stays in videos");
        console.log("DISPLAY_QML_PASS");
        const snapshot = Quickshell.env("ASTRAL_DISPLAY_SCREENSHOT");
        if (snapshot) displayPage.grabToImage(result => { root.check(result.saveToFile(snapshot), "page snapshot"); Qt.quit(); });
        else Qt.quit();
      }
    }
  }
}
