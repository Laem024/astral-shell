import QtQuick
import Quickshell

// A pending marker closes privacy before compositor confirmation. Only the
// authenticated locker clears it; a crashed/failed locker leaves privacy closed.
Scope {
  id: root
  Command { id: request; timeout: 2000 }
  function begin(done) {
    request.run(["mkdir", "-p", "-m", "700", "--", Paths.runtime], code => {
      if (code !== 0) { if (done) done(false); return; }
      request.run(["touch", "--", Paths.runtime + "/lock-pending"], code => { if (done) done(code === 0); });
    });
  }
  function setLocked(locked, done) {
    request.run(["busctl", "--system", "call", "org.freedesktop.login1",
      "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session",
      "SetLockedHint", "b", locked ? "true" : "false"], (code, output, error) => {
      if (code !== 0) console.warn("Cannot update logind lock hint: " + error);
      if (code === 0 && !locked) request.run(["rm", "-f", "--", Paths.runtime + "/lock-pending"], code => { if (done) done(code === 0); });
      else if (done) done(code === 0);
    });
  }
}
