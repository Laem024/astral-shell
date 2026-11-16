pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
  property bool cancelling: false
  property string allocated: ""
  property double startedAt: 0
  property int duration: 0
  readonly property bool busy: !["idle", "error"].includes(state)
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../display/capture.sh").toString().replace(/^file:\/\//, ""))
  function prepare(operation, source, output, sound): bool {
    if (busy || SessionData.blocked || (operation === "record" && !["monitor", "region"].includes(source))) return false;
    kind = operation; mode = source; monitor = output; audio = sound;
    window = mode === "window" && kind === "shot" ? WindowData.activeWindow : null;
    windowReady = false; cancelling = false; error = ""; resultFile = ""; allocated = ""; startedAt = 0; duration = 0; state = "hiding";
    return true;
  }
  // NativePanel calls this only after its layer surface becomes invisible.
  function panelHidden(): void { if (state === "hiding") settle.restart(); }
  function run(): void {
    if (SessionData.blocked) { state = "idle"; return; }
    if (mode === "window" && kind === "shot" && !window) { fail("The active window has closed."); return; }
    state = "preparing";
    worker.command = ["bash", helper, mode === "window" && kind === "shot" ? "allocate" : kind, mode, monitor, audio];
    worker.running = true;
  }
  function stop(): void {
    if (worker.running) {
      if (kind === "shot" || state === "selecting") { cancelling = true; worker.signal(15); }
      else { if (state === "recording") updateDuration(); state = "finalizing"; worker.write("stop\n"); }
    }
    else if (busy) { settle.stop(); discard(); captureTimeout.stop(); window = null; state = "idle"; }
  }
  function fail(message): void { error = message; state = "error"; window = null; captureTimeout.stop(); }
  function saved(file): void {
    if (kind === "shot") lastScreenshot = file;
    else lastVideo = file;
    resultFile = file; state = "idle"; window = null; captureTimeout.stop();
    NotificationData.localFile(kind === "shot" ? "Screenshot saved" : "Recording saved", file);
  }
  Timer { id: settle; interval: 180; onTriggered: root.run() }
  function updateDuration(): void {
    if (startedAt > 0) duration = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
  }
  // Poll across second boundaries instead of letting a slightly early tick
  // leave the counter a full second behind. Finalization keeps its last value.
  Timer { interval: 100; repeat: true; running: root.state === "recording"; onTriggered: root.updateDuration() }
  Connections { target: SessionData; function onBlockedChanged() { if (SessionData.blocked) root.stop(); } }
  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (root.busy && root.kind === "record" && root.monitor !== ""
          && !Quickshell.screens.some(screen => screen.name === root.monitor)) root.stop();
    }
  }
  Component.onDestruction: { if (worker.running) worker.write("stop\n"); if (allocated) discard(); }
  Process {
    id: worker
    stdinEnabled: true
    stderr: StdioCollector { id: errors }
    stdout: SplitParser {
      onRead: line => {
        if (line.startsWith("saved\t")) { if (!root.cancelling) root.saved(line.slice(6)); }
        else if (line.startsWith("output\t")) root.monitor = line.slice(7);
        else if (line.startsWith("allocated\t")) root.allocated = line.slice(10);
        else if (line === "cancelled") root.state = "idle";
        else if (line === "recording" || line.startsWith("recording\t")) {
          const timestamp = Number(line.slice(10));
          root.startedAt = timestamp > 0 ? timestamp : Date.now();
          root.updateDuration();
          root.state = "recording";
        }
        else if (["selecting", "preparing", "finalizing"].includes(line)) {
          if (root.state === "recording") root.updateDuration();
          root.state = line;
        }
      }
    }
    onExited: (code, status) => {
      if (root.cancelling) { root.discard(); root.window = null; root.state = "idle"; return; }
      if (code !== 0 || status !== 0) root.fail(errors.text.trim() || "Capture failed.");
      else if (root.allocated && root.window) { root.windowReady = true; captureTimeout.restart(); }
      else if (root.busy) root.fail("Capture ended without a saved file.");
    }
  }
  Timer { id: captureTimeout; interval: 5000; onTriggered: { root.discard(); root.fail("Window capture timed out or is unsupported."); } }
  function verifyWindow(file): void {
    windowReady = false; allocated = ""; window = null;
    worker.command = ["bash", helper, "verify", "window", file]; worker.running = true;
  }
  function discard(): void {
    windowReady = false;
    if (allocated) Quickshell.execDetached(["rm", "-f", "--", allocated]);
    allocated = "";
  }
  Loader {
    id: windowLoader
    active: root.windowReady && root.window !== null && root.allocated !== ""
    source: active ? Qt.resolvedUrl("../display/WindowCapture.qml") : ""
    // The window component is loaded only when a compositor capture is requested.
    // qmllint disable missing-property
    onLoaded: item.service = root
    // qmllint enable missing-property
  }
}
