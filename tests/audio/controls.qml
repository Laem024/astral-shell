import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design
Scope {
  id: root
  QtObject { id: testSettings; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: testSettings }
  Window {
    visible: true; width: 360; height: 200
    TestCase { id: mouse; name: "AudioInteraction"; when: false }
    Column {
      width: parent.width
      Panel.VolumeControl { id: outputControl; tokens: theme; node: root.target; label: "Test output"; width: parent.width }
      Panel.VolumeControl { id: inputControl; tokens: theme; node: root.input; label: "Test input"; width: parent.width }
    }
  }
  function muteButton(item) {
    if (item.text === "Mute" || item.text === "Unmute") return item;
    if (item.children) for (let child of item.children) {
      const button = muteButton(child);
      if (button) return button;
    }
    return null;
  }
  function slider(item) {
    if (item.from !== undefined && item.to !== undefined) return item;
    if (item.children) for (let child of item.children) {
      const control = slider(child);
      if (control) return control;
    }
    return null;
  }
  property var input: null
  property int stage: 0
  property int ticks: 0
  property var target: null
  property var stream: null
  Timer {
    interval: 100; running: true; repeat: true
    onTriggered: {
      const a = Data.AudioData;
      if (++root.ticks > 80) { console.log("AUDIO_FAIL", root.stage); Qt.quit(); return; }
      if (root.stage === 0) {
        root.target = a.outputs.find(n => n.name === "astral_audio_test");
        root.stream = a.playback.find(n => n.properties["application.name"] === "astral-audio-test");
        root.input = a.inputs.find(n => n.name === "astral_audio_input_test");
        if (!root.target || !root.stream || !root.input) return;
        a.setVolume(root.input, 0.31);
        a.setVolume(root.target, 0.37); a.setVolume(root.stream, 0.23);
        mouse.mouseClick(root.muteButton(outputControl));
        mouse.mouseClick(root.muteButton(inputControl));
        a.toggleMute(root.stream); root.stage++;
      } else if (root.stage === 1 && a.percent(root.target) === 37 && a.percent(root.stream) === 23 && root.target.audio.muted && root.stream.audio.muted && root.input.audio.muted && a.percent(root.input) === 31) {
        mouse.mouseClick(root.muteButton(outputControl));
        mouse.mouseClick(root.muteButton(inputControl));
        a.toggleMute(root.stream);
        a.setVolume(root.target, 0.61); a.setVolume(root.stream, 0.49); root.stage++;
      } else if (root.stage === 2 && a.percent(root.target) === 61 && a.percent(root.stream) === 49 && !root.target.audio.muted && !root.stream.audio.muted && !root.input.audio.muted) {
        const control = root.slider(outputControl);
        mouse.mouseClick(control, control.width * 0.25, control.height / 2);
        const mic = root.slider(inputControl);
        mouse.mouseClick(mic, mic.width * 0.2, mic.height / 2);
        root.stage++;
      } else if (root.stage === 3 && a.percent(root.target) < 50 && a.percent(root.input) < 31) {
        const control = root.slider(outputControl);
        mouse.mouseClick(control, control.width * 0.8, control.height / 2);
        const mic = root.slider(inputControl);
        mouse.mouseClick(mic, mic.width * 0.8, mic.height / 2);
        root.stage++;
      } else if (root.stage === 4 && a.percent(root.target) > 70 && a.percent(root.input) > 70) {
        console.log("AUDIO_CONTROLS_PASS"); Qt.quit();
      }
    }
  }
}
