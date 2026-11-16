import QtQuick
import Quickshell
import "common" as Common

ShellRoot {
  id: root
  readonly property string entry: Common.Overlays.entry("astral-session") || Quickshell.env("ASTRAL_SESSION_ENTRY")
  readonly property string action: Quickshell.env("ASTRAL_SESSION_ACTION") || "toggle"
  Common.InstanceControl { id: service; entry: root.entry; target: "session" }
  Common.StartupLock {
    id: mutex
    key: "session-menu-" + Qt.md5(root.entry)
    onAcquired: service.ensure(ok => {
      if (!ok) { root.finish(1, "Session menu did not become ready."); return; }
      if (root.action === "daemon") { root.finish(0, ""); return; }
      root.privacy(() => service.ipc("toggle", [""], (code, output) => {
        const reply = output.trim();
        root.finish(code === 0 && ["ok", "blocked"].includes(reply) ? 0 : 1, reply);
      }));
    })
    onFailed: message => root.finish(1, message)
  }
  function finish(code, message) { mutex.release(); if (message) console.log(message); Qt.exit(code); }
  function privacy(done) {
    Common.Privacy.check(allowed => { if (allowed) done(); else finish(0, "blocked"); });
  }
  Timer { interval: 30000; running: true; onTriggered: root.finish(1, "Session menu command timed out.") }
  Component.onCompleted: {
    if (!entry) { finish(2, "Missing session entry."); return; }
    if (action === "close" || action === "close-active") {
      service.ipc(action === "close" ? "close" : "closeActive", [], (code, output) => {
        const reply = output.trim();
        if (code === 0 && (action === "close" ? reply === "ok" : ["closed", "inactive"].includes(reply))) { finish(0, reply); return; }
        service.absent(missing => finish(missing ? 0 : 1, missing ? "inactive" : "Cannot safely determine session menu state."));
      });
      return;
    }
    if (action === "daemon") mutex.acquire(); else privacy(() => mutex.acquire());
  }
}
