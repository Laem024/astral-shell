pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import Quickshell

// Only streams explicitly tagged as notification/event audio are affected.
// Device mute, volumes, media playback and communication streams stay intact.
Scope {
  id: root
  property bool active: false
  property var nodes: []
  Instantiator {
    model: root.nodes
    delegate: QtObject {
      id: stream
      required property var modelData
      readonly property var audio: modelData ? modelData.audio : null
      readonly property string role: modelData && modelData.properties
        ? String(modelData.properties["media.role"] || "").toLowerCase() : ""
      readonly property bool shouldMute: root.active && !!audio
        && (role === "notification" || role === "event")
      property bool applied: false
      property bool wasMuted: false
      function update(): void {
        if (shouldMute && !applied) {
          wasMuted = audio.muted;
          applied = true;
          audio.muted = true;
        } else if (!shouldMute && applied) restore();
      }
      function restore(): void {
        applied = false;
        if (audio && audio.muted) audio.muted = wasMuted;
      }
      onShouldMuteChanged: update()
      Component.onCompleted: update()
      Component.onDestruction: if (applied) restore()
      property Connections changes: Connections {
        target: stream.audio
        function onMutedChanged() {
          if (stream.applied && stream.shouldMute && !stream.audio.muted) stream.audio.muted = true;
        }
      }
    }
  }
}
