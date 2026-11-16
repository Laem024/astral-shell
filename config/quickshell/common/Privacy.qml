pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property bool ready: false
  property bool blocked: true
  property string hint: ""
  property bool checking: false
  property var waiters: []
  Command { id: probe; timeout: 2000 }
  function complete(value, pendingLock) {
    hint = value;
    blocked = !!pendingLock || hint !== "no";
    ready = true;
    checking = false;
    const callbacks = waiters;
    waiters = [];
    for (const done of callbacks) done(!blocked);
  }
  function check(done) { waiters.push(done); refresh(); }
  function refresh() {
    if (checking) return;
    checking = true;
    probe.run(["test", "-e", Paths.runtime + "/lock-pending"], code => {
      if (code !== 0 && code !== 1) { complete(""); return; }
      const pendingLock = code === 0;
      probe.run(["loginctl", "show-session", Quickshell.env("XDG_SESSION_ID") || "auto", "--property=LockedHint", "--value"], (code, output) =>
        complete(code === 0 ? output.trim() : "", pendingLock));
    });
  }
  Timer { interval: 500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
