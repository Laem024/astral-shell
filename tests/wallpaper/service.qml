import QtQuick
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/astral-wallpaper/Logic.js" as Logic
import "../../config/quickshell/common" as Common
import "../../config/quickshell/astral-wallpaper/wallhaven/WallhavenLogic.js" as Remote

Scope {
  id: root
  property int stage: 0
  property int completed: 0
  property var expectedSettings: null
  Wallpaper.WallpaperService { id: service; settings: Common.SettingsData; blocked: false; screens: [] }
  function check(ok, message) { if (!ok) { console.error("WALLPAPER_FAIL: " + message); Qt.exit(1); } }
  // Object key order is irrelevant; array order and the complete key set matter.
  function equal(a, b) {
    if (a === b) return true;
    if (a === null || b === null || typeof a !== "object" || typeof b !== "object") return false;
    if (Array.isArray(a) !== Array.isArray(b)) return false;
    const ak = Object.keys(a).sort(), bk = Object.keys(b).sort();
    return ak.length === bk.length && ak.every((key, i) => key === bk[i] && equal(a[key], b[key]));
  }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      if (!service.ready || service.scanning || service.dirty) return;
      if (root.stage === 0) {
        root.check(service.warning.includes("invalid"), "corrupt state falls back");
        root.check(service.entries.length >= 12 && service.entries.some(e => e.name.includes("$(touch INJECTED)")), "NUL library catalog preserves special paths");
        root.check(service.entries.some(e => e.name.includes("\n") && e.name.includes("\t")), "NUL catalog preserves newlines and tabs");
        const snapshot = JSON.stringify(service.state);
        const savedKey = service.keySaved; service.setKey("invalid\nkey");
        root.check(service.keySaved === savedKey, "invalid key rejected");
        const latest = Remote.parse(JSON.stringify({data: [], meta: {current_page: 1, last_page: 26216}}));
        root.check(latest.meta.last_page === 26216, "latest feed accepts more than 10000 pages");
        for (const payload of ['{', '{}', JSON.stringify({data:new Array(101).fill({}),meta:{current_page:1,last_page:1}}), JSON.stringify({data:[],meta:{current_page:2,last_page:1}}), JSON.stringify({data:[],meta:{current_page:1,last_page:0}}), JSON.stringify({data:[],meta:{current_page:1,last_page:1.5}}), JSON.stringify({data:[],meta:{current_page:1,last_page:9007199254740992}})]) {
          let rejected = false; try { Remote.parse(payload); } catch (e) { rejected = true; }
          root.check(rejected, "invalid or oversized response rejected");
        }
        root.check(Remote.searchUrl({query: "", page: 1}, "").includes("sorting=date_added"), "empty search uses latest");
        root.check(Remote.searchUrl({query: "space", page: 1}, "").includes("sorting=relevance"), "keyword search uses relevance");
        root.check(Remote.searchUrl({query: "", page: 1, filters: {sorting: "toplist", topRange: "1w", resolutions: "2560x1440"}}, "").includes("topRange=1w"), "toplist and exact resolution filters");
        for (const filters of [{categories: "000"}, {purity: "001"}, {sorting: "invalid"}, {colors: "bad"}, {ratios: "16x9&apikey=bad"}, {resolutions: "1920x1080", atleast: "1920x1080"}]) {
          let rejected = false;
          try { Remote.searchUrl({query: "", page: 1, filters: filters}, ""); } catch (e) { rejected = true; }
          root.check(rejected, "invalid filters or unauthenticated NSFW rejected");
        }
        service.update("minutes", -1);
        root.check(JSON.stringify(service.state) === snapshot, "invalid preference rejected");
        root.check(Logic.fileUrl("/a #?%/b.png") === "file:///a%20%23%3F%25/b.png", "URL encoding");
        for (const name of ["motion.mp4", "motion.webm", "motion.mkv", "motion.mp4"]) service.thumbnails.request(service.state.folder + "/" + name, path => {
          root.check(path.endsWith(".jpg"), "queued thumbnail completed"); root.completed++;
        });
        service.update("minutes", 42); service.update("fade", 33); service.update("random", false);
        root.stage = 1;
      } else if (root.stage === 1 && root.completed === 4) {
        root.check(Common.Privacy.blocked, "unknown logind state blocks privacy");
        const before = JSON.parse(JSON.stringify(Common.SettingsData.value));
        root.check(Common.SettingsData.setMode("light"), "shared theme write");
        before.mode = "light"; root.expectedSettings = before;
        root.check(equal(Common.SettingsData.value, before), "theme preserves every other setting");
        root.stage = 2;
      } else if (root.stage === 2) {
        Common.SettingsData.file.reload();
        Common.SettingsData.file.waitForJob();
        root.check(equal(JSON.parse(Common.SettingsData.file.text()), root.expectedSettings), "saved theme preserves every other setting");
        root.check(equal(Common.SettingsData.value, root.expectedSettings), "reloaded theme preserves every other setting");
        console.log("WALLPAPER_SERVICE_PASS (invalid state, special paths, bounded thumbnails, validation, shared theme, unknown privacy)"); Qt.quit();
        root.stage = 3;
      }
    }
  }
}
