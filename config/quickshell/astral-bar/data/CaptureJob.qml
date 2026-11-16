import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common
import "CaptureLogic.js" as Logic

Scope {
  id: root
  property string state: "idle"
  property string kind: "shot"
  property string mode: "monitor"
  property string monitor: ""
  property string audio: "none"
  property string geometry: ""
  property string allocated: ""
  property string resultFile: ""
  property string error: ""
  property double startedAt: 0
  property bool cancelling: false
  property bool stopRequested: false
  property bool finishing: false
  property bool preparation: false
  readonly property bool busy: !["idle", "error"].includes(state)
  signal completed(string file)
  signal windowAllocated(string file)
  Common.Command { id: command }
  Common.Command { id: transport }
  CaptureAudio { id: sound }
  function start(value) {
    if (busy) return false;
    try { Logic.request(value); } catch (e) { error = String(e); state = "error"; return false; }
    kind = value.kind; mode = value.mode; monitor = value.monitor; audio = value.audio;
    geometry = ""; resultFile = ""; allocated = ""; error = ""; startedAt = 0; cancelling = false; stopRequested = false; finishing = false;
    state = "preparing"; preparation = true;
    command.run(["xdg-user-dir", kind === "shot" ? "PICTURES" : "VIDEOS"], (code, output) => {
      if (cancelled()) return;
      const base = code === 0 && output.trim().startsWith("/") && output.trim() !== Common.Paths.home ? output.trim() : Common.Paths.home + (kind === "shot" ? "/Pictures" : "/Videos");
      const directory = base + (kind === "shot" ? "/Screenshots" : "/ScreenRecordings");
      command.run(["mkdir", "-p", "--", directory], (code, out, failure) => {
        if (cancelled()) return;
        if (code !== 0) { finish(failure || "Cannot create capture directory."); return; }
        command.run(["mktemp", directory + "/" + new Date().toISOString().replace(/[:.]/g, "-") + "-XXXXXX." + (kind === "shot" ? "png" : "mkv")], (code, output) => {
          allocated = code === 0 ? output.trim() : "";
          if (cancelled()) return;
          if (!allocated) { finish("Cannot allocate capture file."); return; }
          if (mode === "window") { preparation = false; windowAllocated(allocated); windowTimeout.restart(); }
          else if (mode === "region") select();
          else validateOutput();
        });
      });
    });
    return true;
  }
  function cancelled() { if (!cancelling) return false; preparation = false; finish(""); return true; }
  function select() {
    state = "selecting";
    selector.stdinEnabled = true;
    selector.running = true;
  }
  Process {
    id: selector
    // slurp reads optional rectangles from stdin until EOF before showing its UI.
    // Explicitly close the managed pipe instead of inheriting a live parent pipe.
    onStarted: stdinEnabled = false
    onRunningChanged: if (!running && root.state === "selecting") Qt.callLater(() => {
      if (!selector.running && root.state === "selecting" && !root.finishing) root.finish("Could not start the region selector.");
    })
    command: ["slurp", "-d", "-f", "%x,%y %wx%h"]
    stdout: StdioCollector { id: selection }
    stderr: StdioCollector { id: selectionError }
    onExited: (code, status) => {
      if (root.cancelled()) return;
      if (code !== 0 || status !== 0) { root.cancelling = !selectionError.text.trim(); root.finish(selectionError.text.trim()); return; }
      try { root.geometry = Logic.region(selection.text).text; }
      catch (e) { root.finish(String(e)); return; }
      root.state = "preparing"; settle.restart();
    }
  }
  Timer { id: settle; interval: 150; onTriggered: root.validateOutput() }
  function validateOutput() {
    command.run(["hyprctl", "-j", "monitors"], (code, output) => {
      if (cancelled()) return;
      try {
        if (code !== 0) throw new Error("Cannot query displays.");
        const displays = JSON.parse(output);
        if (kind === "record" && geometry) monitor = Logic.outputForRegion(Logic.region(geometry), displays);
        else if (!geometry && !displays.some(m => m.name === monitor)) throw new Error("Monitor disconnected.");
      } catch (e) { finish(String(e)); return; }
      if (kind === "shot") {
        command.run(["grim"].concat(geometry ? ["-g", geometry] : ["-o", monitor]).concat([allocated]), (code, output, failure) => {
          preparation = false;
          if (cancelled()) return;
          if (code !== 0) finish(failure || "Screenshot failed."); else verify();
        });
      } else sound.prepare(audio, failure => {
        preparation = false;
        if (cancelling) { finish(""); return; }
        if (failure) { finish(failure); return; }
        const args = ["wf-recorder", "-y", "-o", monitor, "-c", "libx264", "-C", "aac", "-f", allocated];
        if (geometry) args.push("-g", geometry);
        if (sound.source) args.push("--audio=" + sound.source);
        recorder.command = args; recorder.running = true;
      });
    });
  }
  Process {
    id: recorder
    onRunningChanged: if (!running && root.busy && root.startedAt === 0 && !root.finishing) Qt.callLater(() => {
      if (!recorder.running && root.busy && root.startedAt === 0 && !root.finishing) root.finish("Could not start wf-recorder.");
    })
    stderr: StdioCollector { id: recordingError }
    onStarted: { root.startedAt = Date.now(); root.state = root.stopRequested ? "finalizing" : "recording"; }
    onExited: (code, status) => {
      stopDeadline.stop();
      if (root.error || code !== 0 || status !== 0) root.finish(root.error || recordingError.text.trim() || "Recording failed; the file may be incomplete.");
      else root.verify();
    }
  }
  Timer {
    interval: 1000; repeat: true; running: root.state === "recording" && sound.bluetoothInput
    onTriggered: if (!transport.running) transport.run(["pw-dump"], (code, output) => {
      try {
        if (code === 0 && JSON.parse(output).some(row => row.type === "PipeWire:Interface:Node" && row.info && row.info.state === "error" && /^bluez_(input|output)/.test(row.info.props["node.name"] || ""))) {
          root.error = "Bluetooth microphone transport failed. Reconnect the headset."; root.stop();
        }
      } catch (_) {}
    })
  }
  function verifyWindow(file) { if (file === allocated) { windowTimeout.stop(); verify(); } }
  function verify() {
    command.run(["stat", "-c", "%s", "--", allocated], (code, output) => {
      if (code !== 0 || Number(output.trim()) <= 0) finish("Capture file is empty.");
      else finish("", true);
    });
  }
  function stop() {
    if (!busy || finishing || stopRequested) return;
    stopRequested = true;
    if (recorder.running) {
      state = "finalizing";
      // Give a newly started encoder time to install its signal handlers.
      if (Date.now() - startedAt < 400) earlyStop.restart(); else recorder.signal(2);
      stopDeadline.restart();
    } else {
      cancelling = true; sound.cancelled = true;
      if (selector.running) selector.signal(15);
      else if (!preparation && !command.running) finish("");
      // A pending preparation callback owns cleanup, including module IDs.
    }
  }
  Timer { id: earlyStop; interval: 400; onTriggered: if (recorder.running) recorder.signal(2) }
  Timer { id: stopDeadline; interval: 15000; onTriggered: { root.error = "Recorder did not finalize in time; the file may be incomplete."; recorder.signal(9); } }
  Timer { id: windowTimeout; interval: 5000; onTriggered: root.finish("Window capture timed out or is unsupported.") }
  function discard() { stop(); }
  function fail(message) { finish(message); }
  function finish(message, success) {
    if (finishing) return;
    finishing = true; preparation = false; windowTimeout.stop(); settle.stop();
    state = "finalizing";
    sound.cleanup(failure => {
      error = message || failure;
      const file = allocated;
      function complete() {
        allocated = ""; finishing = false;
        if (success && !cancelling && !message) { resultFile = file; state = error ? "error" : "idle"; completed(file); }
        else state = error ? "error" : "idle";
      }
      if (file && (!success || cancelling)) command.run(["stat", "-c", "%s", "--", file], (code, output) => {
        if (kind === "shot" || code !== 0 || Number(output.trim()) === 0) command.run(["rm", "-f", "--", file], complete);
        else { error = error || "Incomplete recording retained at " + file; complete(); }
      }); else complete();
    });
  }
}
