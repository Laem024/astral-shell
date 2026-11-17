import QtQuick
import Quickshell
import "astral-settings" as Settings
import "astral-settings/Logic.js" as Logic
import "common" as Common

Settings.SettingsRoot {
  id:root
  property int step:0
  property bool waiting:false
  Common.Command { id:fixture }
  function assert(ok,message) { if(!ok) { console.error('ASSERT: '+message); Qt.exit(1); } }
  function trial() { const list=desktopService.inventory.map(Logic.monitorFromLive); list[0].scale=1.25; desktopService.beginDisplay(list); }
  Timer {
    interval:80; running:true; repeat:true
    onTriggered: {
      const s=root.desktopService, w=root.settingsWindow;
      if(!s.ready || Common.Privacy.blocked || s.command.running || s.query.running || s.busy || root.waiting) return;
      if(root.step===0) {
        root.assert(s.apiReason==='','Lua API detected from repl result');
        root.open(); root.open(); root.assert(w.visible,'repeated open');
        for(const key of ['input.kb_layout','input.sensitivity','input.accel_profile','input.touchpad.natural_scroll'])
          root.assert(w.unavailable({scope:'desktop',key:key})==='','input control available: '+key);
        const before=Logic.clone(Common.SettingsData.value);
        root.assert(Common.SettingsData.updateFields(before,{workspaceCount:12}),'atomic preference update');
        root.assert(Common.SettingsData.value.workspaceCount===12,'preference write verified');
        root.assert(!Common.SettingsData.updateFields(before,{workspaceCount:14}),'external conflict rejected');
        root.assert(Common.SettingsData.updateFields(Common.SettingsData.value,{workspaceCount:10}),'restore preference');
        w.navigate('Bar',false); w.edit({scope:'bar',key:'margin'},12); w.navigate('General',false);
        root.assert(w.page==='Bar','pending changes block navigation');
        w.continueNavigation(); root.assert(w.page==='General','discard navigation');
        root.trial(); s.deadline.interval=20; root.step=1;
      } else if(root.step===1 && !s.testing) {
        root.assert(!s.error,'timeout rollback: '+s.error); root.assert(s.inventory[0].scale===1,'timeout restores scale');
        root.trial(); s.deadline.interval=1000; root.step=2;
      } else if(root.step===2 && s.testing) {
        root.close(); root.assert(!w.visible,'close hides window'); root.step=3;
      } else if(root.step===3 && !s.testing) {
        root.assert(s.inventory[0].scale===1,'close restores scale'); root.open();
        root.waiting=true; fixture.run(['touch',Quickshell.env('ASTRAL_SETTINGS_FIXTURE')+'/fail'],()=>{ root.waiting=false; root.trial(); root.step=4; });
      } else if(root.step===4 && !s.testing) {
        root.assert(s.inventory[0].scale===1,'partial command failure restores scale');
        root.open(); root.trial(); root.step=6;
      } else if(root.step===6 && s.testing) {
        root.waiting=true; fixture.run(['touch',Quickshell.env('ASTRAL_SETTINGS_FIXTURE')+'/locked'],()=>{root.waiting=false; root.step=5;});
      }
    }
  }
  Timer {
    interval:100; running:true; repeat:true
    onTriggered: {
      const s=root.desktopService;
      if(root.step===5 && Common.Privacy.blocked && !s.testing && !s.busy) {
        root.assert(!root.settingsWindow.visible,'lock hides settings'); root.assert(s.inventory[0].scale===1,'lock restores scale');
        console.log('ASTRAL_SETTINGS_RUNTIME_PASS'); Qt.quit();
      }
    }
  }
}
