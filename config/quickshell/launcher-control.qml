import QtQuick
import Quickshell
import Quickshell.Io
import "common" as Common

ShellRoot {
  id: root
  readonly property string entry: Common.Overlays.entry("astral-launcher") || Quickshell.env("ASTRAL_LAUNCHER_ENTRY")
  readonly property string action: Quickshell.env("ASTRAL_LAUNCHER_ACTION") || "toggle"
  readonly property string monitor: Quickshell.env("ASTRAL_LAUNCHER_MONITOR") || ""
  readonly property string lockPath: Common.Paths.runtime + "/launcher-" + Qt.md5(entry) + ".lock"
  property bool finishing: false
  property double deadline: 0
  property int peerIndex: 0
  readonly property var peers: [
    {entry:Common.Overlays.entry("astral-polkit"), target:"polkit"},
    {entry:Common.Overlays.entry("astral-session"), target:"session"},
    {entry:Common.Overlays.entry("astral-wallpaper"), target:"wallpaper-carousel"},
    {entry:Common.Overlays.entry("astral-wallpaper"), target:"wallpaper"},
    {entry:Common.Overlays.entry("astral-bar"), target:"bar"},
    {entry:Common.Overlays.entry("astral-clipboard"), target:"clipboard"},
    {entry:Common.Overlays.entry("astral-overview"), target:"overview"},
    {entry:Common.Overlays.entry("astral-shortcuts"), target:"shortcuts"},
    {entry:entry, target:"launcher"}
  ]
  Common.Command { id: request; timeout: 2000 }
  function finish(code, message) { finishing = true; lock.stdinEnabled = false; if (message) console.log(message); Qt.exit(code); }
  function ipc(path, target, method, args, done) {
    request.run(["qs", "ipc", "-p", path, "call", target, method].concat(args || []), done);
  }
  function privacy(done) {
    Common.Privacy.check(allowed => { if (allowed) done(); else finish(0, "blocked"); });
  }
  function perform() {
    privacy(() => ipc(entry, "launcher", "toggle", [monitor], (code, output) => {
      const reply = output.trim();
      finish(code === 0 && ["ok", "blocked"].includes(reply) ? 0 : 1, reply);
    }));
  }
  function poll() {
    ipc(entry, "launcher", "state", [], (code, output) => {
      if (code === 0 && output.trim() === "ready") { perform(); return; }
      if (Date.now() >= deadline) { finish(1, "Launcher service did not become ready."); return; }
      retry.restart();
    });
  }
  Timer { id: retry; interval: 80; onTriggered: root.poll() }
  function start() {
    deadline = Date.now() + 6000;
    request.run(["qs", "-d", "--no-duplicate", "-p", entry], code => {
      if (code !== 0) { finish(1, "Could not start launcher service."); return; }
      if (action === "daemon") finish(0, ""); else poll();
    });
  }
  function absent(path, done) {
    request.run(["qs", "list", "--json", "-p", path], (code, output) => {
      let missing = false;
      try { const rows = JSON.parse(output); missing = code === 0 && Array.isArray(rows) && rows.length === 0; }
      catch (e) { missing = code === 0 && /^No running instances for /.test(output.trim()); }
      done(missing);
    });
  }
  function closeNext() {
    if (peerIndex >= peers.length) {
      privacy(() => request.run(["hyprctl", "dispatch", "hl.dsp.window.close()"], code => finish(code, "inactive")));
      return;
    }
    const peer = peers[peerIndex++];
    if (!peer.entry) { closeNext(); return; }
    ipc(peer.entry, peer.target, "closeActive", [], (code, output) => {
      const reply = output.trim();
      if (code === 0 && reply === "closed") { finish(0, "closed"); return; }
      if (code === 0 && reply === "inactive") { closeNext(); return; }
      // Unknown responses from a live instance must never close an application.
      absent(peer.entry, missing => {
        if (missing) closeNext();
        else finish(1, "Cannot safely determine overlay state.");
      });
    });
  }
  function acquire() {
    if (!Quickshell.env("XDG_RUNTIME_DIR").startsWith("/")) { finish(1, "XDG_RUNTIME_DIR must be available."); return; }
    request.run(["mkdir", "-p", "-m", "700", "--", Common.Paths.runtime], code => {
      if (code !== 0) { finish(1, "Cannot prepare launcher runtime storage."); return; }
      request.run(["chmod", "700", "--", Common.Paths.runtime], code => {
        if (code !== 0) { finish(1, "Cannot secure launcher runtime storage."); return; }
        request.run(["touch", "--", lockPath], code => {
          if (code !== 0) { finish(1, "Cannot prepare launcher startup lock."); return; }
          request.run(["chmod", "600", "--", lockPath], code => {
            if (code !== 0) { finish(1, "Cannot secure launcher startup lock."); return; }
            lock.running = true;
          });
        });
      });
    });
  }
  Process {
    id: lock
    command: ["flock", "--exclusive", "--timeout", "8", root.lockPath, "tee"]
    stdinEnabled: true
    onStarted: write("acquired\n")
    stdout: SplitParser { onRead: line => { if (line === "acquired") root.start(); } }
    stderr: StdioCollector {}
    onExited: if (!root.finishing) root.finish(1, "Could not acquire launcher startup lock.")
    onRunningChanged: if (!running && !root.finishing) Qt.callLater(() => {
      if (!lock.running && !root.finishing) root.finish(1, "Could not start launcher startup lock.");
    })
  }
  Timer { interval: 15000; running: true; onTriggered: root.finish(1, "Launcher command timed out.") }
  Component.onCompleted: {
    if (!entry) { finish(2, "Missing launcher entry."); return; }
    if (action === "close") { ipc(entry, "launcher", "close", [], () => finish(0, "")); return; }
    if (action === "close-active") { privacy(closeNext); return; }
    if (action === "daemon") acquire(); else privacy(acquire);
  }
}
