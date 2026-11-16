pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Logic.js" as Logic

Singleton {
  id: root
  property bool loading: false
  property string error: ""
  property var categories: []
  property int total: 0
  property bool pendingRefresh: false
  readonly property string command: "hyprctl"

  function refresh(): void {
    if (request.running) { pendingRefresh = true; return; }
    loading = true;
    error = "";
    request.running = true;
  }

  Process {
    id: request
    command: [root.command, "-j", "binds"]
    stdout: StdioCollector { id: output }
    stderr: StdioCollector { id: errors }
    onExited: (code, status) => {
      root.loading = false;
      if (code !== 0 || status !== 0) {
        root.error = errors.text.trim() || "Could not read Hyprland shortcuts.";
        root.categories = [];
        root.total = 0;
      } else {
        const parsed = Logic.parseBinds(output.text);
        root.categories = parsed.categories;
        root.total = parsed.total;
        root.error = parsed.error;
      }
      if (root.pendingRefresh) {
        root.pendingRefresh = false;
        Qt.callLater(() => { if (!request.running) root.refresh(); });
      }
    }
  }
}
