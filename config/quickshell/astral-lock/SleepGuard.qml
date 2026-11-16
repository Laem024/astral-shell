import QtQuick
import Quickshell
import Quickshell.Io
import "../common" as Common

// A delay inhibitor gives the independent locker time to secure the compositor
// before logind sleeps, including lid-close and external suspend requests.
Scope {
  id: root
  property string sessionPath: ""
  property bool preparing: false
  property bool expectSleepValue: false
  property bool releasing: false
  Common.Command { id: lookup; timeout: 2000 }
  Common.Command { id: lockRequest; timeout: 15000 }
  Common.InstanceControl {
    id: locker
    entry: Common.Overlays.entry("astral-lock")
    target: "lock"
  }
  function secured() { if (preparing) { releasing = true; inhibitor.stdinEnabled = false; } }
  function secure() {
    if (lockRequest.running) return;
    // A suspend command may already hold the action mutex. Query its independent
    // locker first so the sleep guard never waits behind that same command.
    locker.ipc("state", [], (code, output) => {
      if (code === 0 && output.trim() === "secure") { secured(); return; }
      lockRequest.run(["astral-lock", "lock"], code => {
        if (code === 0) secured();
        else console.warn("Lock was not confirmed before sleep; check the locker.");
      });
    });
  }
  function event(line) {
    if (line.includes("member=PrepareForSleep")) { expectSleepValue = true; return; }
    if (expectSleepValue && /^\s*boolean (true|false)\s*$/.test(line)) {
      expectSleepValue = false;
      preparing = line.trim() === "boolean true";
      if (preparing) secure();
      else { releasing = false; inhibitor.stdinEnabled = true; inhibitor.running = true; }
    }
    if (sessionPath && line.includes("path=" + sessionPath + ";") && /member=Lock\s*$/.test(line)) secure();
    // Logind Unlock signals never bypass PAM.
  }
  Process {
    id: monitor
    command: ["dbus-monitor", "--system",
      "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'",
      "type='signal',interface='org.freedesktop.login1.Session',member='Lock',path='" + root.sessionPath + "'"]
    stdout: SplitParser { onRead: line => root.event(line) }
    stderr: StdioCollector {}
    onExited: reconnect.restart()
  }
  Process {
    id: inhibitor
    command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=astral-lock",
      "--why=Secure the session before sleep", "tee"]
    stdinEnabled: true
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: if (!root.preparing) reconnect.restart()
  }
  function connect() {
    lookup.run(["busctl", "--system", "--json=short", "call", "org.freedesktop.login1",
      "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "GetSession", "s",
      Quickshell.env("XDG_SESSION_ID") || "auto"], (code, output) => {
      try {
        const path = JSON.parse(output).data[0];
        if (code !== 0 || typeof path !== "string" || !/^\/org\/freedesktop\/login1\/session\/[A-Za-z0-9_]+$/.test(path)) throw new Error("Invalid session");
        sessionPath = path;
        if (!monitor.running) monitor.running = true;
        if (!preparing && !inhibitor.running) { releasing = false; inhibitor.stdinEnabled = true; inhibitor.running = true; }
      } catch (_) { reconnect.restart(); }
    });
  }
  Timer { id: reconnect; interval: 3000; onTriggered: root.connect() }
  Component.onCompleted: connect()
}
