import QtQuick
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/common" as Common

Scope {
  id: root
  property bool started: false
  property int stage: 0
  readonly property string scenario: Quickshell.env("ASTRAL_NETWORK_CASE")
  Wallpaper.WallpaperService { id: service; settings: Common.SettingsData; screens: []; blocked: false }
  function check(ok, message) { if (!ok) { console.error("WALLPAPER_FAIL: " + message); Qt.exit(1); } }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      if (!service.ready || service.scanning || service.remoteBusy) return;
      if (!root.started) {
        root.started = true;
        root.check(service.keySaved, "saved key loaded by a fresh service");
        if (["interrupted", "damaged"].includes(root.scenario)) service.download({path:"https://w.wallhaven.cc/full/ab/wallhaven-abc123.png"}, "shared");
        else service.search('spaces & "quotes"', 2);
        return;
      }
      if (root.scenario === "success") {
        root.check(!service.error && service.remoteEntries.length === 1 && service.page === 2 && service.lastPage === 26216, "authenticated search and large pagination: " + service.error);
        if (root.stage === 0) {
          root.stage = 1;
          service.search("   ", 1);
          return;
        }
        if (root.stage === 1) {
          root.check(service.query === "", "blank query lists latest wallpapers");
          root.stage = 2;
          service.searchFilters = {categories: "010", purity: "110", sorting: "random", order: "asc", ratios: "16x9", atleast: "1920x1080", colors: "0066cc"};
          service.search("filtered", 1);
          return;
        }
        if (root.stage === 2) {
          root.stage = 3;
          service.searchFilters = {categories: "100"};
          service.search("filtered", 3);
          return;
        }
      }
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
