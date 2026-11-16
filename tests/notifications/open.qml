import QtQuick
import Quickshell
import "../../config/quickshell/astral-bar/data" as Data

Scope {
  id: root
  Data.NotificationService {
    id: service
    applications: ({fileManager: ["missing-manager"], terminal: ["fake-terminal", "$literal"], videoPlayer: ["fake-video", "--flag"]})
  }
  property int ticks: 0
  property string special: "/a dir/$HOME;`echo no` #?.mp4"
  Component.onCompleted: {
    service.openFile(special, false);
    service.openFile("/other/$(touch NEVER).png", false);
    service.openFile("/folder with spaces/image.png", true);
    service.openFile("/failure/image.png", false);
  }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      if (++root.ticks > 100) { console.error("OPEN_FAIL timeout"); Qt.exit(1); }
      if (service.entries.some(entry => entry.launchState === "opening")) return;
      const failed = service.entries.find(entry => entry.file === "/failure/image.png");
      if (!failed || failed.launchState !== "error" || !failed.launchMessage) { console.error("OPEN_FAIL missing error"); Qt.exit(1); }
      if (service.entries.filter(entry => entry.id !== failed.id).some(entry => entry.launchState !== "idle")) { console.error("OPEN_FAIL launch state " + JSON.stringify(service.entries)); Qt.exit(1); }
      console.log("NOTIFICATION_OPEN_PASS"); Qt.quit();
    }
  }
}
