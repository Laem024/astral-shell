import QtQuick
import Quickshell
import Quickshell.Io
import "astral-bar/data" as Data

ShellRoot {
  id: root
  readonly property string directory: Quickshell.env("ASTRAL_LIVE_DIR")
  FileView { id: marker; path: root.directory + "/accepted"; printErrors: false; blockLoading: true; blockWrites: true }
  Data.NotificationService {
    id: service
    applications: ({fileManager: ["astral-nonexistent-file-manager"],
      terminal: [root.directory + "/fixture", "a b", "$(touch INJECTED)", "; touch INJECTED", "$HOME", "'quoted'"], videoPlayer: []})
  }
  Component.onCompleted: {
    if (marker.text() === "accepted") return;
    service.openFile(directory + "/working dir/file.png", true);
  }
  Timer {
    interval: 50; repeat: true; running: marker.text() !== "accepted"
    onTriggered: {
      if (!service.entries.length || service.entries[0].launchState === "opening") return;
      if (service.entries[0].launchState !== "idle") { console.error("LIVE_LAUNCH_FAIL " + service.entries[0].launchMessage); Qt.exit(1); return; }
      marker.setText("accepted");
    }
  }
}
