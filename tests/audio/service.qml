import QtQuick
import Quickshell
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design
Scope {
  QtObject { id: testSettings; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: testSettings }
  Panel.SoundPage { id: page; tokens: theme; width: 300; height: 420 }
  Panel.SoundPage { tokens: theme; width: 240; height: 300 }
  Timer { interval: 1500; running: true; onTriggered: {
    const audio = Data.AudioData;
    function checkGeometry(item) {
      if (item.from !== undefined && item.to !== undefined && item.height < 24)
        throw new Error("Volume slider has no usable hit area");
      if (item.children) for (let child of item.children) checkGeometry(child);
    }
    checkGeometry(page);
    if (Data.SystemData.volume !== audio.percent(audio.sink)) throw new Error("Bar and panel differ");
    if (audio.outputs.some(n => n.isStream || !n.isSink)) throw new Error("Invalid output");
    if (audio.inputs.some(n => n.isStream || n.isSink)) throw new Error("Invalid input");
    if (audio.playback.some(n => !n.isStream || !n.isSink)) throw new Error("Invalid playback stream");
    if (audio.percent(null) !== -1) throw new Error("Missing node must be unavailable");
    // Invalid operations must be harmless and never affect active devices.
    audio.setVolume(null, 0.5);
    audio.toggleMute(null);
    audio.selectInput(null);
    audio.selectOutput(null);
    console.log("AUDIO_SMOKE_PASS", Data.AudioData.available, Data.AudioData.outputs.length, Data.AudioData.inputs.length, Data.AudioData.playback.length);
    Qt.quit();
  } }
}
