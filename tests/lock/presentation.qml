import QtQuick
import QtQuick.Window
import Quickshell
import "../../config/quickshell/astral-lock" as Lock
import "../../config/quickshell/common" as Common

ShellRoot {
  id: root
  property int stage: 0
  QtObject { id: testSettings; property var value: Common.SettingsData.value }
  Common.Theme { id: theme; settings: testSettings }
  QtObject {
    id: testMedia
    property var player: ({})
    property string title: "<b>Plain title</b>"
    property string artist: "Artist"
    property bool playing: false
    property bool canPrevious: false
    property bool canToggle: false
    property bool canNext: false
    property real position: 42
    property real length: 210
    property real progress: 0.2
    property int previousCalls: 0
    property int toggleCalls: 0
    property int nextCalls: 0
    function previous() { if (canPrevious) previousCalls++; }
    function toggle() { if (canToggle) toggleCalls++; }
    function next() { if (canNext) nextCalls++; }
  }
  Window {
    id: window
    width: 1440; height: 900; visible: true
    Lock.LockContent {
      id: content
      anchors.fill: parent; tokens: theme; settings: testSettings; media: testMedia
      displayName: "Astral Test"; secure: true
      dateTime: new Date(2026, 10, 10, 21, 41)
    }
  }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
    return null;
  }
  function check(condition, message) { if (!condition) throw new Error(message); }
  Timer {
    interval: 100; running: true
    onTriggered: {
      if (root.stage !== 0) return;
      try {
        const field = root.find(content, "lockPassword");
        root.check(field.echoMode === TextInput.Password && field.passwordMaskDelay === 0, "hidden password");
        root.check(!field.enabled && !content.promptReady, "no input outside PAM prompt");
        root.check(content.wide, "wide composition");
        root.check(root.find(content, "lockClock").text === "09:41", "12-hour clock uses matching hour and period");
        const player = root.find(content, "lockMedia");
        root.check(player.visible && player.width > 250, "integrated wide player");
        const play = root.find(player, "lockPlay");
        root.check(!play.enabled, "unsupported transport disabled");
        testMedia.canToggle = true;
        play.clicked(); root.check(testMedia.toggleCalls === 1, "transport action");
        const title = root.find(player, "lockTrackTitle");
        root.check(title.textFormat === Text.PlainText, "metadata is plain text");
        content.promptReady = true;
        field.text = "simulated test input";
        content.clear(); root.check(field.text === "", "clear input");
        field.text = "simulated test input";
        content.busy = true; root.check(field.text === "", "clear state transition");
        root.check(!field.enabled && root.find(content, "lockBusy").running, "busy disables input and shows progress");
        content.error = true; content.message = "Incorrect password. Try again.";
        root.check(root.find(content, "lockAuthStatus").text === content.message, "visible authentication error");
        content.secure = false; root.check(!field.enabled, "wait compositor");
        testSettings.value = Object.assign({}, testSettings.value, {mode: "light", scale: 2, clockFormat: "24h", lockScreen: {showProfile: false, showMusic: false}});
        window.width = 320; window.height = 240;
        root.check(root.find(content, "lockClock").text === "21:41", "24-hour clock");
        root.check(!content.showProfile && !content.showMusic && content.factor <= theme.scale, "small light presentation");
        root.check(content.color.a === 1, "opaque background");
        testMedia.player = null;
        root.check(!content.showMusic, "no player");
        // Simulate the activeFocus loss seen when the seat keyboards are
        // removed and re-added across suspend. Typing must work again without
        // a click or a screen change, and already typed characters must survive
        // the transient loss.
        content.secure = true; content.busy = false; content.promptReady = true;
        field.forceActiveFocus();
        field.text = "nota";
        field.focus = false;
        root.check(!field.activeFocus, "focus loss simulated");
        root.stage = 1;
      } catch (error) { console.log("PRESENTATION_FAIL", error); Qt.quit(); }
    }
  }
  Timer {
    interval: 250; running: root.stage === 1
    onTriggered: {
      try {
        const field = root.find(content, "lockPassword");
        root.check(content.promptReady && !content.busy, "prompt stays interactive");
        root.check(field.activeFocus, "password focus reclaimed without interaction");
        root.check(field.text === "nota", "typed password survives transient focus loss");
        console.log("PRESENTATION_PASS");
      } catch (error) { console.log("PRESENTATION_FAIL", error); }
      Qt.quit();
    }
  }
}
