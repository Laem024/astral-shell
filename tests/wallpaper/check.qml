import QtQuick
import QtQuick.Window
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/astral-wallpaper/Logic.js" as Logic
import "../../config/quickshell/common" as Settings
import "../../config/quickshell/common" as Design

Scope {
  id: root
  property int stage: 0
  property int ticks: 0
  property int manualApplications: 0
  property int beforeDownloadApplications: 0
  property int appliedAt: 0
  property string before: ""
  property string beforeA: ""
  property var displays: [{name: "A", x: -960, y: 0, width: 960, height: 1080}, {name: "B", x: 0, y: -100, width: 1920, height: 1080}]
  readonly property string library: Quickshell.env("HOME") + "/Pictures/Wallpapers"
  function check(value, message) { if (!value) { console.error("WALLPAPER_FAIL: " + message); Qt.exit(1); } }
  function entry(name) { return controller.available.find(e => e.name === name).path; }
  QtObject {
    id: preferences
    property var value: Settings.SettingsData.value
    property var modes: []
    function setMode(mode) { modes.push(mode); value = Object.assign({}, value, {mode: mode}); }
  }
  Design.Theme { id: theme; settings: preferences }
  Wallpaper.WallpaperService { id: controller; settings: preferences; blocked: false; screens: root.displays }
  Connections { target: controller; function onApplied() { root.manualApplications++; } }
  Window {
    visible: true; width: 1000; height: 700
    Repeater { model: root.displays; delegate: Wallpaper.WallpaperRenderer { service: controller } }
    Wallpaper.WallpaperContent { id: content; anchors.fill: parent; service: controller; tokens: theme }
  }
  Component.onCompleted: {
    check(Logic.classify("light/a.png") === "light" && Logic.classify("nested/dark/a.png") === "shared", "folder classification");
    const s = Logic.defaults(library);
    check(Logic.theme("light") === "light" && Logic.theme("dark") === "dark" && Logic.theme("other") === "dark", "collection follows the module theme");
    check(s.collection === undefined, "wallpaper state no longer stores a collection");
    const entries = [{path: "a"}, {path: "b"}, {path: "c"}];
    check(Logic.choose(entries, "a", true, 0) === "b", "random avoids immediate repeat");
    check(Logic.choose(entries, "c", false) === "a", "sequential wraps");
    check(Logic.choose([], "old", false) === "old" && Logic.choose([{path:"a"}], "a", true) === "a", "small collections");
    s.selections.dark.common = "gone";
    check(Logic.assignments(s, "dark", entries, ["A"]).A === "a", "missing assignment falls back");
    s.layout = "Per monitor"; s.selections.dark.monitors.A = "b";
    check(Logic.assignments(s, "dark", entries, ["A", "B"]).B === "a", "new monitor fallback");
    check(Logic.parse(JSON.stringify(s), library).selections.dark.monitors.A === "b", "assignment round trip");
    check(Logic.parse(JSON.stringify(Object.assign({}, s, {collection: "Auto"})), library).collection === undefined, "legacy collection preference is ignored");
    for (const bad of ['{', '{}', JSON.stringify(Object.assign({}, s, {minutes: -1})), JSON.stringify(Object.assign({}, s, {selections: {}}))]) {
      let rejected = false; try { Logic.parse(bad, library); } catch(e) { rejected = true; }
      check(rejected, "invalid state rejected");
    }
    const legacy = {common: "legacy", monitors: {DISCONNECTED: "retained"}};
    Logic.ensureLayouts(legacy); legacy.common = "changed"; legacy.layouts.Span.common = "span";
    check(legacy.layouts.Mirror.common === "legacy" && legacy.layouts["Per monitor"].monitors.DISCONNECTED === "retained", "legacy assignments seeded independently by layout");
    const b = Logic.bounds(displays);
    check(b.x === -960 && b.y === -100 && b.width === 2880 && b.height === 1180, "logical mixed-scale span geometry");
    check(Logic.fileUrl("/a #?%/b.png") === "file:///a%20%23%3F%25/b.png", "file URL escaping");
  }
  Timer {
    interval: 80; repeat: true; running: true
    onTriggered: {
      if (++root.ticks > 240) { root.check(false, "timeout stage " + root.stage + ": " + controller.error); return; }
      if (!controller.ready || controller.scanning || controller.transaction) return;
      if (root.stage === 0) {
        if (!controller.activePaths.A) return;
        root.check(controller.warning.length > 0, "corrupt state recovery warning");
        root.check(controller.entries.length === 12, "recursive supported formats scan");
        root.check(!controller.available.some(e => e.theme === "light"), "light collection excluded");
        root.check(!controller.state.rotation && controller.state.minutes === 30, "rotation defaults");
        controller.update("fade", 50); controller.apply(root.entry("motion.mp4"), "A"); root.stage = 1;
      } else if (root.stage === 1) {
        if (controller.renderers.A.showingSerial >= 0) return;
        root.check(controller.activePaths.A.endsWith("motion.mp4") && controller.activePaths.B === controller.activePaths.A, "video mirror commit");
        root.appliedAt = controller.renderers.A.currentMedia.position;
        controller.blocked = true; root.stage = 2;
      } else if (root.stage === 2) {
        root.check(controller.renderers.A.currentMedia.paused, "lock pauses media");
        controller.blocked = false; controller.update("layout", "Span"); root.stage = 3;
      } else if (root.stage === 3) {
        root.check(controller.geometry.width === 2880, "span uses logical coordinates");
        controller.apply(root.entry("motion.gif"), "A"); root.stage = 4;
      } else if (root.stage === 4) {
        if (controller.renderers.A.showingSerial >= 0) return;
        root.check(controller.renderers.A.currentMedia.kind === "gif", "GIF transition");
        controller.update("layout", "Per monitor"); root.stage = 5;
      } else if (root.stage === 5) {
        root.beforeA = controller.activePaths.A;
        controller.apply(root.entry("still.webp"), "B"); root.stage = 6;
      } else if (root.stage === 6) {
        root.check(controller.activePaths.A === root.beforeA && controller.activePaths.B.endsWith("still.webp"), "per-monitor assignments");
        root.before = controller.activePaths.B;
        controller.apply(root.entry("broken.png"), "B"); root.stage = 7;
      } else if (root.stage === 7) {
        root.check(controller.error.length > 0 && controller.activePaths.B === root.before, "damaged image preserves active wallpaper");
        controller.error = ""; preferences.value = Object.assign({}, preferences.value, {mode: "light"}); root.stage = 8;
      } else if (root.stage === 8) {
        root.check(controller.collection === "light" && !controller.available.some(e => e.theme === "dark"), "theme switch");
        controller.apply(root.entry("light.png"), "A"); root.stage = 9;
      } else if (root.stage === 9) {
        root.check(controller.activePaths.A.endsWith("light.png"), "light selection saved");
        preferences.value = Object.assign({}, preferences.value, {mode: "dark"}); root.stage = 10;
      } else if (root.stage === 10) {
        root.check(controller.activePaths.B === root.before, "restore dark assignment");
        root.displays = [root.displays[0]]; root.stage = 11;
      } else if (root.stage === 11) {
        root.check(controller.state.selections.dark.monitors.B === root.before, "disconnected assignment retained");
        root.displays = [{name:"A", x:0,y:0,width:960,height:1080},{name:"B",x:960,y:0,width:1920,height:1080}]; root.stage = 12;
      } else if (root.stage === 12) {
        root.check(controller.activePaths.B === root.before, "reconnected monitor restored");
        controller.apply(root.entry("motion.gif"), "A"); root.stage = 121;
      } else if (root.stage === 121) {
        controller.update("random", false); controller.update("rotation", true); controller.rotate(); root.stage = 13;
      } else if (root.stage === 13) {
        root.check(controller.activePaths.B !== root.before, "rotation changes each monitor");
        controller.update("rotation", false);
        content.tab = "Settings"; root.stage = 14;
      } else if (root.stage === 14) {
        content.tab = "Wallhaven"; controller.search("astral test", 2); root.stage = 15;
      } else if (root.stage === 15) {
        if (controller.remoteBusy) return;
        root.check(controller.remoteEntries.length === 1 && controller.page === 2 && controller.lastPage === 3, "Wallhaven pagination");
        controller.download(controller.remoteEntries[0], "light"); root.stage = 16;
      } else if (root.stage === 16) {
        if (controller.remoteBusy || controller.scanning) return;
        root.check(controller.entries.some(e => e.name === "wallhaven-abc123.png" && e.theme === "light"), "download incorporated in chosen collection");
        preferences.value = Object.assign({}, preferences.value, {animations:false});
        root.check(controller.fadeDuration === 0, "animations disabled overrides fade");
        root.beforeA = controller.activePaths.A;
        root.beforeDownloadApplications = root.manualApplications;
        controller.download(controller.remoteEntries[0], "shared", "B");
        root.stage = 17;
      } else if (root.stage === 17) {
        if (controller.remoteBusy || controller.scanning || controller.transaction) return;
        root.check(controller.activePaths.B === root.library + "/wallhaven-abc123.png", "download and apply uses validated local file");
        root.check(controller.activePaths.A === root.beforeA, "download and apply respects target monitor");
        root.check(root.manualApplications === root.beforeDownloadApplications + 1 && !controller.pendingDownloadApply, "download and apply completes once");
        controller.assign(root.library + "/light/light.png", "light", "B", "Per monitor");
        root.stage = 171;
      } else if (root.stage === 171) {
        if (controller.transaction) return;
        root.check(controller.state.selections.light.monitors.B.endsWith("light.png") && controller.collection === "light", "assignment switches collection");
        root.check(controller.activePaths.B.endsWith("light.png") && controller.activePaths.A.endsWith("light.png"), "assignment applies immediately");
        root.check(root.manualApplications === root.beforeDownloadApplications + 2, "assignment reports a manual application");
        root.beforeDownloadApplications = root.manualApplications;
        controller.download({path: "https://example.invalid/file.png"}, "shared", "B");
        root.stage = 18;
      } else if (root.stage === 18) {
        if (controller.remoteBusy || controller.scanning || controller.transaction) return;
        root.check(controller.error.length > 0 && !controller.pendingDownloadApply && root.manualApplications === root.beforeDownloadApplications, "failed download never applies and clears pending request");
        controller.download(controller.remoteEntries[0], "shared", "B");
        controller.blocked = true;
        root.stage = 19;
      } else if (root.stage === 19) {
        if (controller.remoteBusy || controller.scanning || controller.transaction) return;
        root.check(!controller.pendingDownloadApply && root.manualApplications === root.beforeDownloadApplications, "lock during download prevents application");
        controller.blocked = false;
        content.tab = "Local";
        controller.setTheme("Light");
        root.stage = 20;
      } else if (root.stage === 20 && !controller.dirty) {
        root.check(controller.collection === "light" && preferences.modes.includes("light"), "theme updates the module mode and collection");
        console.log("WALLPAPER_QML_PASS (logic, real media, transitions, rollback, assignment, theme, outputs, rotation, state, UI, Wallhaven)"); Qt.quit();
      }
    }
  }
}
