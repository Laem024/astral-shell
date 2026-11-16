import QtQuick
import Quickshell
import "common" as Common

// Independent of the bar/menu: it survives their reloads and owns no unlock API.
ShellRoot {
  id: root
  readonly property string entry: Common.Overlays.entry("astral-lock") || Quickshell.env("ASTRAL_LOCK_ENTRY")
  readonly property string action: Quickshell.env("ASTRAL_LOCK_ACTION") || "lock"
  readonly property string idleEntry: Common.Overlays.entry("astral-idle") || Quickshell.shellDir + "/idle.qml"
  property bool finishing: false
  Common.Command { id: request }
  Common.SessionHint { id: hint }
  Common.AutomaticPolicy { id: policy }
  Common.InstanceControl { id: locker; entry: root.entry; target: "lock"; readyStates: ["secure"]; loadingStates: ["locking"] }
  Common.InstanceControl { id: idle; entry: root.idleEntry; target: "idle" }
  Common.StartupLock {
    id: mutex
    key: "session-action"
    onAcquired: root.begin()
    onFailed: message => root.finish(1, message)
  }
  function finish(code, message) {
    if (finishing) return;
    finishing = true; mutex.release();
    if (message) console.log(message);
    Qt.exit(code);
  }
  function lockThen(done) {
    hint.begin(ok => {
      if (!ok) { finish(1, "Cannot prepare lock privacy state."); return; }
      locker.ensure(ok => {
        if (!ok) { finish(1, "The compositor has not confirmed the session lock."); return; }
        hint.setLocked(true, ok => {
          if (ok) done(); else finish(1, "Logind has not confirmed lock privacy.");
        });
      });
    });
  }
  function executePower() {
    // Refresh media/inhibitors again after the compositor has secured the lock.
    if (action === "auto-suspend") policy.check(true, allowed => {
      if (!allowed) { finish(0, "blocked"); return; }
      idle.ipc("active", [], (code, output) => {
        if (code === 0 && output.trim() === "true") power("suspend");
        else finish(0, "blocked");
      });
    });
    else power(action);
  }
  function power(name) {
    const command = name === "logout"
      ? ["hyprctl", "-i", Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"), "dispatch", "hl.dsp.exit()"]
      : ["systemctl", "--check-inhibitors=yes", "--no-ask-password", name];
    if (name === "logout" && !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) { finish(1, "Current Hyprland instance is required."); return; }
    request.run(command, (code, output, error) => finish(code, code === 0 ? "" : error || "Session action failed."));
  }
  function perform() {
    if (["lock", "auto-lock", "lid"].includes(action)) { lockThen(() => finish(0, "secure")); return; }
    if (["suspend", "auto-suspend"].includes(action)) { lockThen(executePower); return; }
    if (["logout", "reboot", "poweroff"].includes(action)) { executePower(); return; }
    if (action === "auto-dpms") {
      request.run(["hyprctl", "dispatch", "dpms", "off"], code => finish(code, "")); return;
    }
    if (action === "idle") {
      idle.ensure(ok => {
        if (!ok) { finish(1, "Idle worker did not become ready."); return; }
        idle.ipc("begin", [], (code, output) => finish(code, output.trim()));
      });
      return;
    }
    finish(2, "Invalid lock action.");
  }
  function begin() {
    if (["auto-lock", "auto-dpms", "auto-suspend", "idle", "lid"].includes(action)) {
      policy.check(action === "auto-suspend", allowed => {
        // Keep logind's ordinary lid handling. With caffeine enabled, still lock.
        if (action === "lid") { if (!allowed) perform(); else finish(0, ""); }
        else if (allowed) perform(); else finish(0, "blocked");
      });
    } else perform();
  }
  Timer { interval: 45000; running: true; onTriggered: root.finish(1, "Session command timed out.") }
  Component.onCompleted: {
    if (!entry) { finish(2, "Missing lock entry."); return; }
    if (action === "privacy") {
      Common.Privacy.check(allowed => finish(0, allowed ? "idle" : "locked"));
      return;
    }
    // Activity cancellation must not queue behind a lock/suspend request.
    if (action === "activity") { idle.ipc("cancel", [], () => finish(0, "")); return; }
    mutex.acquire();
  }
}
