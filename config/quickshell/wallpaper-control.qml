import QtQuick
import Quickshell
import Quickshell.Io
import "common" as Common

ShellRoot {
  id: root
  readonly property string entry: Quickshell.env("ASTRAL_WALLPAPER_ENTRY")
  readonly property string action: Quickshell.env("ASTRAL_WALLPAPER_ACTION") || "toggle"
  readonly property string monitor: Quickshell.env("ASTRAL_WALLPAPER_MONITOR") || ""
  readonly property string handler: action === "carousel" ? "wallpaper-carousel" : "wallpaper"
  property double deadline: Date.now() + 6000
  property bool finishing: false
  readonly property string lockPath: Common.Paths.runtime + "/wallpaper-" + Qt.md5(entry) + ".lock"
  Common.Command { id: request; timeout: 2000 }
  function finish(code, message) { finishing = true; lock.stdinEnabled = false; if (message) console.log(message); Qt.exit(code); }
  function ipc(target, method, args, done) { request.run(["qs", "ipc", "-p", entry, "call", target, method].concat(args || []), done); }
  function perform() {
    if (action === "daemon") { finish(0, ""); return; }
    ipc(handler, "toggle", [monitor], code => finish(code, ""));
  }
  function poll() {
    ipc(handler, "state", [], (code, output) => {
      if (code === 0 && output.trim() === "ready") { perform(); return; }
      if (Date.now() >= deadline) { finish(1, "Wallpaper service did not become ready."); return; }
      retry.restart();
    });
  }
  Timer { id: retry; interval: 80; onTriggered: root.poll() }
  function close() {
    ipc("wallpaper-carousel", action === "close" ? "close" : "closeActive", [], (code, output) => {
      if (action === "close-active" && code === 0 && output.trim() === "closed") { finish(0, "closed"); return; }
      const firstKnown = code === 0 && output.trim() === "inactive";
      ipc("wallpaper", action === "close" ? "close" : "closeActive", [], (code, output) => {
        if (action === "close") { finish(0, ""); return; }
        if (firstKnown && code === 0 && ["closed", "inactive"].includes(output.trim())) { finish(0, output.trim()); return; }
        request.run(["qs", "list", "--json", "-p", entry], (code, output) => {
          let absent = false;
          try { absent = code === 0 && JSON.parse(output).length === 0; }
          catch (e) { absent = code === 0 && output.includes("No running instances"); }
          finish(absent ? 0 : 1, absent ? "inactive" : "Cannot safely determine wallpaper window state.");
        });
      });
    });
  }
  function start() {
    deadline = Date.now() + 6000;
    request.run(["qs", "-d", "--no-duplicate", "-p", entry], code => {
      if (code !== 0) { finish(1, "Could not start wallpaper service."); return; }
      if (action === "daemon") finish(0, ""); else poll();
    });
  }
  Process {
    id: lock
    // tee acknowledges acquisition and holds the flock while stdin stays open.
    // Decisions and readiness polling remain in this controller.
    command: ["flock", "--exclusive", "--timeout", "8", root.lockPath, "tee"]
    stdinEnabled: true
    onStarted: write("acquired\n")
    stdout: SplitParser { onRead: line => { if (line === "acquired") root.start(); } }
    stderr: StdioCollector {}
    onExited: if (!root.finishing) root.finish(1, "Could not acquire the wallpaper startup lock.")
    onRunningChanged: if (!running && !root.finishing) Qt.callLater(() => {
      if (!lock.running && !root.finishing) root.finish(1, "Could not start the wallpaper startup lock.");
    })
  }
  Timer { interval: 15000; running: true; onTriggered: root.finish(1, "Wallpaper command timed out.") }
  Component.onCompleted: {
    if (!entry) { finish(2, "Missing wallpaper entry."); return; }
    if (["close", "close-active"].includes(action)) { close(); return; }
    if (!Quickshell.env("XDG_RUNTIME_DIR").startsWith("/")) { finish(1, "XDG_RUNTIME_DIR must be available."); return; }
    request.run(["mkdir", "-p", "-m", "700", "--", Common.Paths.runtime], code => {
      if (code !== 0) { finish(1, "Cannot prepare wallpaper runtime storage."); return; }
      request.run(["chmod", "700", "--", Common.Paths.runtime], code => {
        if (code !== 0) { finish(1, "Cannot secure wallpaper runtime storage."); return; }
        request.run(["touch", "--", lockPath], code => {
          if (code !== 0) { finish(1, "Cannot prepare wallpaper startup lock."); return; }
          request.run(["chmod", "600", "--", lockPath], code => {
            if (code !== 0) { finish(1, "Cannot secure wallpaper startup lock."); return; }
            lock.running = true;
          });
        });
      });
    });
  }
}
