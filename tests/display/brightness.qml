pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Input
import Quickshell
import Quickshell.Io
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design

ShellRoot {
  id: root
  property int step: 0
  property int ticks: 0
  property int moves: 0
  property var slider: null
  property real finalValue: 0
  property double keyStarted: 0
  Process { id: keyboard }
  function check(ok, label) { if (!ok) { console.error("BRIGHTNESS_DRAG_FAIL " + label); Qt.exit(1); } }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
    return null;
  }
  QtObject { id: testSettings; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: testSettings }
  Input.TestEvent { id: mouse }
  Component.onCompleted: { Data.CapturePreferences.selectTask("shot"); Data.CapturePreferences.selectSource("monitor"); }
  FloatingWindow {
    visible: true
    implicitWidth: 400; implicitHeight: 700
    Panel.DisplayPage { id: page; tokens: theme; anchors.fill: parent }
  }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      if (++root.ticks > 120) root.check(false, "timeout");
      if (root.step === 0) {
        if (Data.BrightnessData.monitorModel.count !== 2) return;
        const flick = page.contentItem as Flickable;
        flick.contentY = Math.max(0, flick.contentHeight - flick.height);
        root.step++;
      } else if (root.step === 1) {
        root.slider = root.find(page, "brightnessSlider-eDP-1");
        const slider = root.slider;
        root.check(mouse.mousePress(slider, slider.handle.x + slider.handle.width / 2, slider.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "mouse press delivered");
        root.check(slider.pressed, "initial pointer grab");
        root.step++;
      } else if (root.step === 2) {
        root.check(root.slider === root.find(page, "brightnessSlider-eDP-1"), "delegate survives updates");
        root.check(root.slider.pressed, "grab survives hardware completion");
        if (root.moves++ === 3) Data.BrightnessData.reconcile([
          {name: "eDP-1", device: "intel", backend: "backlight", percent: 12, available: true, reason: ""},
          {name: "DP-1", device: "7", backend: "ddc", percent: 20, available: false, reason: "Unsupported"}]);
        const x = root.slider.width * (0.25 + (root.moves % 6) * 0.1);
        mouse.mouseMove(root.slider, x, root.slider.height / 2, 0, Qt.LeftButton, Qt.NoModifier);
        if (root.moves < 12) return;
        root.finalValue = Math.round(root.slider.value);
        mouse.mouseRelease(root.slider, x, root.slider.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
        root.check(!root.slider.pressed, "explicit release");
        root.step++;
      } else if (root.step === 3) {
        if (Data.BrightnessData.pending || Object.keys(Data.BrightnessData.queued).length) return;
        root.check(Math.abs(Data.BrightnessData.monitorModel.get(0).percent - root.finalValue) < 1, "last drag value confirmed");
        root.keyStarted = Date.now();
        keyboard.command = ["bash", "-c", 'printf "%s\n" "$2" > "$1/external-level"', "brightness-key", Quickshell.env("ASTRAL_TEST_DIR"), "37"];
        keyboard.running = true;
        root.step++;
      } else if (root.step === 4) {
        root.check(Date.now() - root.keyStarted < 1000, "keyboard update is timely");
        if (Math.round(root.slider.value) !== 37) return;
        root.check(root.slider === root.find(page, "brightnessSlider-eDP-1"), "external update preserves control");
        root.check(Data.BrightnessData.monitorModel.get(0).percent === 37, "external decrease reaches model");
        root.keyStarted = Date.now();
        keyboard.command = ["bash", "-c", 'printf "%s\n" "$2" > "$1/external-level"', "brightness-key", Quickshell.env("ASTRAL_TEST_DIR"), "12"];
        keyboard.running = true;
        root.step++;
      } else if (root.step === 5) {
        root.check(Date.now() - root.keyStarted < 1000, "repeated keyboard update is timely");
        if (Math.round(root.slider.value) !== 12) return;
        root.check(Data.BrightnessData.monitors[0].percent === 12, "external decrease reaches public state");
        Data.CapturePreferences.selectTask("record");
        Data.CapturePreferences.selectSource("region");
        Data.CapturePreferences.selectAudio("both");
        Data.CapturePreferences.selectMonitor("DP-1");
        console.log("BRIGHTNESS_DRAG_PASS"); Qt.quit();
      }
    }
  }
}
