import QtQuick
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../common/Defaults.js" as Defaults

ShellRoot {
  id:root
  property bool preview:false
  property alias desktopService:desktop
  property alias settingsWindow:window
  Common.Theme { id:theme; settings:Common.SettingsData }
  Common.SettingsStore { id:bar; path:Qt.resolvedUrl('../astral-bar/settings.json'); scope:'bar'; defaults:Defaults.bar }
  DesktopService { id:desktop; preview:root.preview; windowOpen:window.visible }
  SettingsWindow { id:window; service:desktop; tokens:theme; barStore:bar; preview:root.preview; visible:root.preview }
  Common.Command { id:focusCommand; timeout:2000 }
  function open() {
    if(!preview && Common.Privacy.blocked) return 'blocked';
    if(!preview) Common.Overlays.dismiss('astral-settings');
    window.show(); window.raise(); window.requestActivate();
    // Wayland activation requests may be ignored without a token; use the unique title.
    if(!preview) focusCommand.run(['hyprctl','dispatch','focuswindow','title:^(Astral Settings)$'],()=>{});
    return 'ok';
  }
  function close() { window.navigate('',true); return 'ok'; }
  IpcHandler {
    target:'settings'
    function state():string { return desktop.ready ? 'ready' : 'loading'; }
    function open():string { return root.open(); }
    function toggle():string { return window.visible ? root.close() : root.open(); }
    function close():string { return root.close(); }
    function closeActive():string { if(!window.visible) return 'inactive'; root.close(); return 'closed'; }
  }
  Connections {
    target:Common.Privacy
    function onBlockedChanged() {
      if(!root.preview && Common.Privacy.blocked) { desktop.revert(); window.hide(); }
    }
  }
}
