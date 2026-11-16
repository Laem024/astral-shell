import QtQuick
import Quickshell

Scope {
  id: root
  required property string module
  required property string entry
  required property string action
  property var arguments: []
  signal finished(int code, string message)
  InstanceControl { id: service; entry: root.entry; target: root.module }
  StartupLock {
    id: mutex
    key: root.module + "-" + Qt.md5(root.entry)
    onFailed: message => root.finish(1, message)
    onAcquired: service.ensure(ok => {
      if (!ok) { root.finish(1, "Panel did not become ready."); return; }
      if (root.action === "daemon") { root.finish(0, ""); return; }
      Privacy.check(allowed => {
        if (!allowed) { root.finish(0, "blocked"); return; }
        service.ipc(root.action === "alt-tab" ? "altTab" : root.action, root.arguments, (code, output) => {
          const reply = output.trim();
          root.finish(code === 0 && ["ok", "blocked"].includes(reply) ? 0 : 1, reply);
        });
      });
    })
  }
  function finish(code, message) { mutex.release(); finished(code, message); }
  function start() {
    if (!entry) { finish(2, "Missing panel entry."); return; }
    if (["close", "close-active"].includes(action)) {
      service.ipc(action === "close" ? "close" : "closeActive", [], (code, output) => {
        const reply = output.trim();
        if (code === 0 && (action === "close" ? reply === "ok" : ["closed", "inactive"].includes(reply))) { finish(0, reply); return; }
        service.absent(missing => finish(missing ? 0 : 1, missing ? "inactive" : "Cannot safely determine panel state."));
      });
    } else if (action === "daemon") mutex.acquire();
    else Privacy.check(allowed => { if (allowed) mutex.acquire(); else finish(0, "blocked"); });
  }
  Timer { interval: 30000; running: true; onTriggered: root.finish(1, "Panel command timed out.") }
  Component.onCompleted: Qt.callLater(start)
}
