import QtQuick
import Quickshell
import Quickshell.Io
import "common" as Common
ShellRoot {
  id: root
  readonly property string owner: Quickshell.env("ASTRAL_OVERLAY_OWNER")
  readonly property string expected: owner === "astral-launcher" ? "close carousel\nclose wallpaper\nclose bar\nclose session" : "close carousel\nclose wallpaper\nclose launcher\nclose session"
  property int ticks: 0
  FileView { id: calls; path: Quickshell.env("ASTRAL_SESSION_DIR") + "/calls"; blockLoading: true }
  Component.onCompleted: Common.Overlays.dismiss(owner)
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      calls.reload(); calls.waitForJob();
      if (calls.text().trim().endsWith(root.expected)) { console.log("LAUNCHER_OVERLAYS_PASS " + root.owner); Qt.quit(); }
      else if (++root.ticks > 80) { console.error("LAUNCHER_FAIL overlay coordination"); Qt.exit(1); }
    }
  }
}
