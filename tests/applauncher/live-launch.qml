import QtQuick
import Quickshell
import Quickshell.Io
import "common" as Common

ShellRoot {
  id: root
  readonly property string directory: Quickshell.env("ASTRAL_LIVE_DIR")
  FileView { id: marker; path: root.directory + "/accepted"; printErrors: false; blockLoading: true; blockWrites: true }
  Common.ApplicationLaunch { id: launch }
  Component.onCompleted: {
    if (marker.text() === "accepted") return;
    launch.launch([directory + "/fixture", "a b", "$(touch INJECTED)", "; touch INJECTED", "$HOME", "'quoted'"], directory + "/working dir", (ok, detail) => {
      if (!ok) { console.error("LIVE_LAUNCH_FAIL " + detail); Qt.exit(1); return; }
      marker.setText("accepted");
    });
  }
}
