import QtQuick
import Quickshell
import "astral-settings" as Settings

ShellRoot {
  Settings.DesktopService { id: service }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      if (!service.ready) return;
      if (!service.apiReason) {
        console.error('ASSERT: unsupported API reply must block desktop edits');
        Qt.exit(1); return;
      }
      service.beginDisplay([]);
      if (service.testing || service.busy) {
        console.error('ASSERT: unsupported API must not start a display trial');
        Qt.exit(1); return;
      }
      console.log('ASTRAL_SETTINGS_CAPABILITIES_PASS');
      Qt.quit();
    }
  }
}
