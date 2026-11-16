import QtQuick
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/common" as Common

Scope {
  id: root
  property bool started: false
  readonly property string scenario: Quickshell.env("ASTRAL_NETWORK_CASE")
  Wallpaper.WallpaperService { id: service; settings: Common.SettingsData; screens: []; blocked: false }
  function check(ok, message) { if (!ok) { console.error("WALLPAPER_FAIL: " + message); Qt.exit(1); } }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      if (!service.ready || service.scanning || service.remoteBusy) return;
      if (!root.started) {
        root.started = true;
        service.setKey("TESTSECRET123"); root.check(service.keySaved, "key saved");
        if (["interrupted", "damaged"].includes(root.scenario)) service.download({path:"https://w.wallhaven.cc/full/ab/wallhaven-abc123.png"}, "shared");
        else service.search('spaces & "quotes"', 2);
        return;
      }
      if (root.scenario === "success") root.check(service.remoteEntries.length === 1 && service.page === 2, "SFW search and pagination");
      else {
        const expected = ({"401":"authentication", "403":"authentication", "429":"rate limit", "500":"HTTP", offline:"Network error", invalid:"Invalid Wallhaven", interrupted:"Network error", damaged:"damaged"})[root.scenario];
        root.check(service.error.includes(expected), root.scenario + ": " + service.error);
        root.check(!service.pendingDownloadApply, "failed request clears destination");
      }
      service.setKey(""); root.check(!service.keySaved, "key cleared");
      console.log("WALLPAPER_NETWORK_PASS (" + root.scenario + ")"); Qt.quit();
    }
  }
}
