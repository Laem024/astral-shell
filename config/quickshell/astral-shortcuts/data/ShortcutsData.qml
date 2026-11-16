pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../common" as Common
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
    request.run([root.command, "-j", "binds"], (code, output, errors) => {
      root.loading = false;
      if (code !== 0) {
        root.error = errors.trim() || "Could not read Hyprland shortcuts.";
        root.categories = []; root.total = 0;
      } else {
        const parsed = Logic.parseBinds(output);
        root.categories = parsed.categories; root.total = parsed.total; root.error = parsed.error;
      }
      if (root.pendingRefresh) { root.pendingRefresh = false; Qt.callLater(root.refresh); }
    });
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { if (event.name === "configreloaded") root.refresh(); }
  }
  Common.Command { id: request; timeout: 5000 }
}
