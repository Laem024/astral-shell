pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common
import "CaptureLogic.js" as Logic

Singleton {
  id: root
  property string state: "idle"
  property string error: ""
  property string resultFile: ""
  property string lastScreenshot: ""
  property string lastVideo: ""
  property string kind: "shot"
  property string mode: "monitor"
  property string monitor: ""
  property string audio: "none"
  property var window: null
  property bool windowReady: false
  readonly property string allocated: shot.allocated
  property double startedAt: 0
  property int duration: 0
  readonly property bool busy: !["idle", "error"].includes(state)
  readonly property string workerPath: Quickshell.shellDir + "/recorder.qml"
  property string client: ""
  property bool connecting: false
  property double connectDeadline: 0
  property bool requested: false
  Common.Command { id: control; timeout: 2500 }
  Common.Command { id: heartbeat; timeout: 2000 }
  CaptureJob {
    id: shot
    onStateChanged: if (root.kind === "shot" && root.state !== "hiding") root.state = state
    onErrorChanged: if (root.kind === "shot") root.error = error
    onWindowAllocated: { root.windowReady = true; }
    onCompleted: file => root.saved(file)
  }
  function prepare(operation, source, output, sound) {
    if (busy || SessionData.blocked) return false;
    try { Logic.request({kind: operation, mode: source, monitor: output, audio: sound}); } catch (_) { return false; }
    kind = operation; mode = source; monitor = output; audio = sound;
    window = source === "window" ? WindowData.activeWindow : null;
    windowReady = false; error = ""; resultFile = ""; startedAt = 0; duration = 0; state = "hiding";
    return true;
  }
  function panelHidden() { if (state === "hiding") settle.restart(); }
  Timer { id: settle; interval: 180; onTriggered: root.run() }
  function run() {
    if (SessionData.blocked) { state = "idle"; return; }
    if (mode === "window" && !window) { fail("The active window has closed."); return; }
    state = "preparing";
    if (kind === "shot") shot.start({kind: kind, mode: mode, monitor: monitor, audio: audio});
    else {
      client = Date.now() + "-" + Math.random().toString(36).slice(2);
      connecting = true; requested = false; connectDeadline = Date.now() + 10000;
      Quickshell.execDetached(["qs", "-d", "--no-duplicate", "-p", workerPath]);
      poll();
    }
  }
  function ipc(method, args, callback) { control.run(["qs", "ipc", "-p", workerPath, "call", "recorder", method].concat(args || []), callback); }
  function poll() {
    if (control.running || kind !== "record" || !busy) return;
    const token = client;
    ipc("status", [], (code, output) => {
      // A reply belongs only to the recording that requested it.
      if (kind !== "record" || client !== token || !busy) return;
      let data;
      try { if (code !== 0) throw new Error(); data = JSON.parse(output); }
      catch (_) { if (!connecting || Date.now() > connectDeadline) fail("Recording worker unavailable."); return; }
      if (connecting) {
        if (Date.now() > connectDeadline) { fail("Recording worker did not become ready."); return; }
        if (!data.ready || data.blocked) return;
        if (!requested) {
          requested = true;
          ipc("start", [token, JSON.stringify({kind: kind, mode: mode, monitor: monitor, audio: audio})], (code, output) => {
            if (kind !== "record" || client !== token || !busy) return;
            if (code !== 0 || output.trim() !== "started") fail("A recording is already running or the session is blocked.");
            else connecting = false;
          });
        }
        return;
      }
      if (data.client !== client) { fail("Recording worker ownership changed."); return; }
      monitor = data.monitor; startedAt = data.startedAt; state = data.state; error = data.error;
      if (data.state === "idle" && data.resultFile && data.resultFile !== resultFile) saved(data.resultFile);
    });
  }
  Timer {
    interval: 500; running: root.kind === "record" && root.busy; repeat: true
    onTriggered: {
      if (!heartbeat.running) heartbeat.run(["qs", "ipc", "-p", root.workerPath, "call", "recorder", "beat", root.client], null);
      root.poll();
    }
  }
  Timer { interval: 100; running: root.state === "recording"; repeat: true; onTriggered: root.duration = Math.max(0, Math.floor((Date.now() - root.startedAt) / 1000)) }
  function stop() {
    if (state === "hiding") { settle.stop(); state = "idle"; return; }
    if (kind === "shot") { windowReady = false; shot.stop(); }
    else if (busy && !control.running) ipc("stop", [client], null);
  }
  function discard() { windowReady = false; shot.stop(); }
  function fail(message) { if (kind === "shot" && shot.busy && !shot.finishing) shot.fail(message); error = message; state = "error"; windowReady = false; window = null; }
  function verifyWindow(file) { windowReady = false; window = null; shot.verifyWindow(file); }
  function saved(file) {
    if (kind === "shot") lastScreenshot = file; else lastVideo = file;
    resultFile = file; state = "idle"; windowReady = false; window = null;
    NotificationData.localFile(kind === "shot" ? "Screenshot saved" : "Recording saved", file);
  }
  Connections { target: SessionData; function onBlockedChanged() { if (SessionData.blocked) root.stop(); } }
  Component.onDestruction: { if (kind === "shot" && allocated) Quickshell.execDetached(["rm", "-f", "--", allocated]); if (kind === "record" && busy) Quickshell.execDetached(["qs", "ipc", "-p", workerPath, "call", "recorder", "stop", client]); }
  Loader {
    active: root.windowReady && root.window !== null && root.allocated !== ""
    source: active ? Qt.resolvedUrl("../display/WindowCapture.qml") : ""
    onLoaded: item.service = root
  }
}
