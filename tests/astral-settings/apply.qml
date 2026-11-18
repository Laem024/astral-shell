import QtQuick
import Quickshell
import "astral-settings" as Settings
import "astral-settings/Logic.js" as Logic
import "common" as Common
Settings.SettingsRoot {
  id:root
  property bool started:false
  property int inputStep:0
  function assert(ok,message) { if(!ok) { console.error('ASSERT: '+message); Qt.exit(1); } }
  Timer {
    interval:80; running:true; repeat:true
    onTriggered: {
      const s=root.desktopService;
      if(root.started || !s.ready || s.query.running || s.discovery.running || s.busy) return;
      root.started=true;
      s.installed={gtk:['FixtureTheme'],qt:['FixtureStyle'],icons:['FixtureIcons'],cursor:['FixtureCursor']};
      const base=Logic.clone(s.value), disk=s.disk(); disk.extension='preserved';
      s.write(s.statePath,JSON.stringify(disk));
      root.assert(s.liveInput.touchpad['tap-to-click']===true,'current tap boolean discovered');
      s.apply(base,{'input.touchpad.tap-to-click':false,'input.kb_layout':'us','themes.dark.gtk':'FixtureTheme','themes.dark.qt':'FixtureStyle','themes.dark.icons':'FixtureIcons','themes.dark.cursor':'FixtureCursor'},Common.SettingsData.value);
    }
  }
  Connections {
    target:root.desktopService
    function onCompleted(ok,message) {
      if(!root.started) return;
      const s=root.desktopService;
      root.assert(ok,message);
      root.assert(s.disk().input.touchpad['tap-to-click']===(root.inputStep===1),'tap preference committed');
      root.assert(s.liveInput.touchpad['tap-to-click']===(root.inputStep===1),'tap live value updated');
      if(root.inputStep===0) {
        root.inputStep=1;
        s.apply(Logic.clone(s.value),{'input.touchpad.tap-to-click':true},Common.SettingsData.value);
        return;
      }
      root.assert(s.disk().extension==='preserved','foreign desktop preference retained');
      root.assert(s.disk().input.kb_layout==='us','input preference committed');
      const gtk=s.read(s.configHome+'/gtk-3.0/settings.ini',false);
      root.assert(gtk.includes('keep=true') && gtk.includes('custom=yes') && gtk.includes('gtk-theme-name=FixtureTheme'),'GTK keys preserved and applied');
      root.assert(s.read(s.configHome+'/gtk-3.0/settings.ini.astral-backup',false).includes('custom=yes'),'GTK backup');
      root.assert(s.read(s.configHome+'/qt6ct/qt6ct.conf',false).includes('style=FixtureStyle'),'Qt style applied');
      root.assert(s.read(s.configHome+'/kitty/kitty.conf',false).includes('color0 #123456'),'Kitty ANSI retained');
      root.assert(s.read(s.luaPath,false).includes('FixtureCursor'),'cursor persisted for compositor reload');
      console.log('ASTRAL_SETTINGS_APPLY_PASS'); Qt.quit();
    }
  }
}
