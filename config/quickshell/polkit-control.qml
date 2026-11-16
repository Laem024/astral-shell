import QtQuick
import Quickshell
import Quickshell.Io
import "common" as Common

ShellRoot {
  id: root
  readonly property string entry: Quickshell.env("ASTRAL_POLKIT_ENTRY")
  readonly property string action: Quickshell.env("ASTRAL_POLKIT_ACTION") || "daemon"
  property double deadline: 0
  property bool finishing: false
  readonly property string lockPath: Common.Paths.runtime + "/polkit-" + Qt.md5(entry) + ".lock"
  Common.Command { id: request; timeout: 2000 }
  function finish(code, message) { finishing = true; lock.stdinEnabled = false; if (message) console.log(message); Qt.exit(code); }
  function ipc(target, method, args, done) { request.run(["qs", "ipc", "-p", entry, "call", target, method].concat(args || []), done); }
  property int attempts: 0
  function ipcState(done) { ipc("polkit", "state", [], done); }
  function present(done) {
    request.run(["qs", "list", "--json", "-p", entry], (code, output) => {
      let absent = false;
      try { const rows = JSON.parse(output); absent = code === 0 && Array.isArray(rows) && rows.length === 0; }
      catch (e) { absent = code === 0 && /^No running instances for /.test(output.trim()); }
      done(!absent);
    });
  }
  function poll() {
    ipcState((code, output) => {
      if (code === 0 && ["ready", "active"].includes(output.trim())) { finish(0, ""); return; }
      if (Date.now() < deadline) { retry.restart(); return; }
      if (attempts >= 3) { finish(1, "The Polkit agent did not register; check for another authentication agent."); return; }
      start(true);
    });
  }
  Timer { id: retry; interval: 80; onTriggered: root.poll() }
  function launch() {
    attempts++;
    deadline = Date.now() + 4000;
    request.run(["qs", "-d", "--no-duplicate", "-p", entry], () => poll());
  }
  function start(replaceLoading) {
    ipcState((code, output) => {
      if (code === 0 && ["ready", "active"].includes(output.trim())) { finish(0, ""); return; }
      // Replace only an instance exposing our known loading state. Other agents
      // are never stopped, and unknown replies fail closed.
      if (code === 0 && output.trim() === "loading") {
        if (!replaceLoading) {
          deadline = Date.now() + 4000;
          retry.restart();
          return;
        }
        request.run(["qs", "kill", "-p", entry], code => {
          if (code !== 0) { finish(1, "Could not stop the Polkit instance."); return; }
          settle.restart();
        });
      } else present(exists => {
        if (exists) finish(1, "Cannot safely determine Polkit instance state.");
        else launch();
      });
    });
  }
  Timer { id: settle; interval: 300; onTriggered: root.launch() }
  function begin() {
    if (action !== "restart") { start(); return; }
    ipcState((code, output) => {
      if (code === 0 && ["loading", "ready", "active"].includes(output.trim())) {
        request.run(["qs", "kill", "-p", entry], code => {
          if (code !== 0) { finish(1, "Could not stop the Polkit instance."); return; }
          settle.restart();
        });
      } else present(exists => {
        if (exists) finish(1, "Cannot safely restart the Polkit instance."); else launch();
      });
    });
  }
  function status() {
    ipcState((code, output) => {
      const state = output.trim();
      if (code === 0 && state === "ready") {
        ipc("polkit", "active", [], (code, output) => {
          const active = output.trim();
          if (code === 0 && ["true", "false"].includes(active)) finish(0, active === "true" ? "active" : "ready");
          else finish(1, "Cannot determine Polkit activity.");
        });
        return;
      }
      if (code === 0 && ["active", "loading"].includes(state)) { finish(0, state); return; }
      present(exists => finish(1, exists ? "Cannot determine Polkit state." : "inactive"));
    });
  }
  Process {
    id: lock
    // tee acknowledges acquisition and holds the flock while stdin stays open.
    // Decisions and readiness polling remain in this controller.
    command: ["flock", "--exclusive", "--timeout", "35", root.lockPath, "tee"]
    stdinEnabled: true
    onStarted: write("acquired\n")
    stdout: SplitParser { onRead: line => { if (line === "acquired") root.begin(); } }
    stderr: StdioCollector {}
    onExited: if (!root.finishing) root.finish(1, "Could not acquire the polkit startup lock.")
    onRunningChanged: if (!running && !root.finishing) Qt.callLater(() => {
      if (!lock.running && !root.finishing) root.finish(1, "Could not start the polkit startup lock.");
    })
  }
  Timer { interval: 60000; running: true; onTriggered: root.finish(1, "Polkit command timed out.") }
  Component.onCompleted: {
    if (!entry) { finish(2, "Missing polkit entry."); return; }
    if (action === "status") { status(); return; }
    if (action === "cancel") {
      ipc("polkit", "cancel", [], (code, output) => {
        const reply = output.trim();
        finish(code === 0 && ["cancelled", "inactive"].includes(reply) ? 0 : 1, code === 0 ? reply : "The Polkit agent is not running.");
      });
      return;
    }
    if (!["daemon", "restart"].includes(action)) { finish(2, "Invalid Polkit action."); return; }
    if (!Quickshell.env("XDG_RUNTIME_DIR").startsWith("/")) { finish(1, "XDG_RUNTIME_DIR must be available."); return; }
    request.run(["mkdir", "-p", "-m", "700", "--", Common.Paths.runtime], code => {
      if (code !== 0) { finish(1, "Cannot prepare polkit runtime storage."); return; }
      request.run(["chmod", "700", "--", Common.Paths.runtime], code => {
        if (code !== 0) { finish(1, "Cannot secure polkit runtime storage."); return; }
        request.run(["touch", "--", lockPath], code => {
          if (code !== 0) { finish(1, "Cannot prepare polkit startup lock."); return; }
          request.run(["chmod", "600", "--", lockPath], code => {
            if (code !== 0) { finish(1, "Cannot secure polkit startup lock."); return; }
            lock.running = true;
          });
        });
      });
    });
  }
}
