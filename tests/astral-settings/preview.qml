import QtQuick
import Quickshell
import "astral-settings" as Settings
import "astral-settings/Logic.js" as Logic
import "common" as Common

Settings.SettingsRoot {
  id:root
  preview:true
  property int step:0
  property bool capturing:false
  readonly property string screenshotDirectory:Quickshell.env('ASTRAL_SETTINGS_SCREENSHOT_DIR') || ''
  Timer {
    interval:150; running:true; repeat:true
    onTriggered: {
      const w=root.settingsWindow;
      if(!root.desktopService.ready || root.capturing) return;
      if(root.step===Logic.pages.length*2+2) {
        console.log('ASTRAL_SETTINGS_PREVIEW_PASS'); Qt.quit(); return;
      }
      const pass=Math.floor(root.step/Logic.pages.length);
      if(root.step<Logic.pages.length*2) {
        w.navigate(Logic.pages[root.step%Logic.pages.length],false);
        Common.SettingsData.value=Object.assign({},Common.SettingsData.value,{mode:pass===0 ? 'dark':'light'});
        if(w.tokens.light!==(pass===1)) { console.error('ASSERT: requested palette was not applied'); Qt.exit(1); }
        w.width=pass===0 ? 1180:w.minimumWidth;
        w.height=pass===0 ? 820:w.minimumHeight;
      } else {
        w.search=root.step===Logic.pages.length*2 ? 'touchpad' : 'hdr';
      }
      const name=root.step+'-'+w.page.replace(/[^a-zA-Z]/g,'');
      root.step++;
      if(root.screenshotDirectory) {
        root.capturing=true;
        Qt.callLater(()=>w.contentItem.grabToImage(result=> {
          if(!result.saveToFile(root.screenshotDirectory+'/'+name+'.png')) { console.error('ASSERT: screenshot failed'); Qt.exit(1); }
          root.capturing=false;
        }));
      }
    }
  }
}
