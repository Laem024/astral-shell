import QtQuick
import QtQuick.Window
import Quickshell
import "." as Lock
import "../common" as Common

// Presentation-only window. Never constructs PAM or a Wayland session lock.
ShellRoot {
  id: root
  property bool previewSuccess: false
  QtObject { id: previewSettings; property var value: Common.SettingsData.value }
  Common.Theme { id: theme; settings: previewSettings }
  QtObject {
    id: previewMedia
    property var player: ({})
    property string title: "Weightless"
    property string artist: "Marconi Union · Ambient Transmissions"
    property bool playing: true
    property bool canPrevious: true
    property bool canToggle: true
    property bool canNext: true
    property real position: 142
    property real length: 489
    property real progress: position / length
    function previous() { position = 0; }
    function toggle() { playing = !playing; }
    function next() { position = 0; }
  }
  Window {
    id: window
    width: Number(Quickshell.env("ASTRAL_LOCK_WIDTH")) || 1440
    height: Number(Quickshell.env("ASTRAL_LOCK_HEIGHT")) || 900
    visible: true
    title: "Astral · Preview (no lock or authentication)"
    Lock.LockContent {
      id: content
      anchors.fill: parent
      tokens: theme; settings: previewSettings; media: previewMedia
      secure: true; promptReady: true
      displayName: "Astral"
      dateTime: new Date(2026, 10, 10, 21, 41)
      onRespond: field => {
        root.previewSuccess = field.text === "demo";
        error = false; message = "Verifying password…"; busy = true;
        simulatedReply.restart();
      }
    }
  }
  Timer {
    id: simulatedReply
    interval: 1800
    onTriggered: {
      if (root.previewSuccess) {
        content.unlocking = true;
        previewExit.start();
        return;
      }
      content.busy = false; content.error = true;
      content.message = "Incorrect password. Try again.";
      content.promptReady = false; content.promptReady = true;
    }
  }
  NumberAnimation {
    id: previewExit
    target: content; property: "exitProgress"
    from: 0; to: 1; duration: previewSettings.value.animations ? 260 : 0
    easing.type: Easing.InCubic
    onFinished: Qt.quit()
  }
  Component.onCompleted: {
    previewSettings.value = Object.assign({}, previewSettings.value, {mode: Quickshell.env("ASTRAL_LOCK_MODE") || "dark"});
    if (Quickshell.env("ASTRAL_LOCK_ERROR")) {
      content.error = true; content.message = "Incorrect password. Try again.";
    }
  }
  Timer {
    interval: 600; running: !!Quickshell.env("ASTRAL_LOCK_SCREENSHOT")
    onTriggered: window.contentItem.grabToImage(result => {
      if (!result.saveToFile(Quickshell.env("ASTRAL_LOCK_SCREENSHOT"))) console.log("PREVIEW_FAIL");
      else console.log("PREVIEW_PASS");
      Qt.quit();
    })
  }
}
