import QtQuick
import Quickshell
import "astral-settings" as Settings
Settings.SettingsRoot {
  id:root
  Timer {
    interval:80; running:true; repeat:true
    onTriggered: {
      const s=root.desktopService;
      if(!s.ready || s.testing || s.busy || s.query.running) return;
      if(s.inventory.length!==1 || s.inventory[0].scale!==1 || s.error) { console.error('Recovery failed: '+s.error); Qt.exit(1); return; }
      console.log('ASTRAL_SETTINGS_RECOVERY_PASS'); Qt.quit();
    }
  }
}
