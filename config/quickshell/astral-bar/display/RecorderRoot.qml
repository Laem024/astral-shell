import QtQuick
import Quickshell
import Quickshell.Io
import "../data" as Data

ShellRoot {
  id: root
  Component.onCompleted: Quickshell.watchFiles = false
  property string client: ""
  property double heartbeat: Date.now()
  Data.CaptureJob { id: job }
  IpcHandler {
    target: "recorder"
    function start(token: string, request: string): string {
      if (job.busy || Data.SessionData.blocked || !token) return "unavailable";
      let value;
      try { value = JSON.parse(request); if (value.kind !== "record") return "invalid"; } catch (_) { return "invalid"; }
      root.client = token; root.heartbeat = Date.now();
      return job.start(value) ? "started" : "invalid";
    }
    function beat(token: string): void { if (token === root.client) root.heartbeat = Date.now(); }
    function stop(token: string): void { if (token === root.client) job.stop(); }
    function status(): string {
      return JSON.stringify({state: job.state, monitor: job.monitor, error: job.error, resultFile: job.resultFile, startedAt: job.startedAt, client: root.client, ready: Data.SessionData.ready, blocked: Data.SessionData.blocked});
    }
  }
  Timer {
    interval: 500; repeat: true; running: true
    onTriggered: {
      if (job.busy && (Date.now() - root.heartbeat > 4000 || Data.SessionData.blocked)) job.stop();
      if (!job.busy && Date.now() - root.heartbeat > 15000) Qt.quit();
    }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (job.busy && job.monitor && !Quickshell.screens.some(screen => screen.name === job.monitor)) job.stop();
    }
  }
}
