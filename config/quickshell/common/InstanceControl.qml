import QtQuick
import Quickshell

Scope {
  id: root
  required property string entry
  required property string target
  property var readyStates: ["ready"]
  property var loadingStates: ["loading"]
  property int startupTimeout: 6000
  property double deadline: 0
  property var completion: null
  Command { id: request; timeout: 2000 }
  function ipc(method, args, done) {
    request.run(["qs", "ipc", "-p", entry, "call", target, method].concat(args || []), done);
  }
  function absent(done) {
    request.run(["qs", "list", "--json", "-p", entry], (code, output) => {
      let missing = false;
      try { const rows = JSON.parse(output); missing = code === 0 && Array.isArray(rows) && rows.length === 0; }
      catch (_) { missing = code === 0 && /^No running instances for /.test(output.trim()); }
      done(missing);
    });
  }
  function complete(ok) { const done = completion; completion = null; if (done) done(ok); }
  function poll() {
    ipc("state", [], (code, output) => {
      if (code === 0 && readyStates.includes(output.trim())) { complete(true); return; }
      if (Date.now() >= deadline) { complete(false); return; }
      retry.restart();
    });
  }
  Timer { id: retry; interval: 80; onTriggered: root.poll() }
  function ensure(done) {
    completion = done;
    deadline = Date.now() + startupTimeout;
    ipc("state", [], (code, output) => {
      const state = output.trim();
      if (code === 0 && readyStates.includes(state)) { complete(true); return; }
      if (code === 0 && loadingStates.includes(state)) { poll(); return; }
      absent(missing => {
        if (!missing) { complete(false); return; }
        request.run(["qs", "-d", "--no-duplicate", "-p", entry], code => {
          if (code !== 0) complete(false); else poll();
        });
      });
    });
  }
}
