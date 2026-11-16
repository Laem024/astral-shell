import QtQuick
import Quickshell
import Quickshell.Io
import "../../config/quickshell/astral-wallpaper" as Wallpaper

Scope {
  id: root
  property int stage: 0
  property int ticks: 0
  property int serialBefore: 0
  property string before: ""
  readonly property string library: Quickshell.env("HOME") + "/Pictures/Wallpapers"
  QtObject {
    id: preferences
    property var value: ({mode: "dark", animations: false})
    property var modes: []
    function setMode(mode) { modes.push(mode); value = Object.assign({}, value, {mode: mode}); }
  }
  Wallpaper.WallpaperService { id: service; settings: preferences; blocked: false; screens: [] }
  function check(ok, message) { if (!ok) { console.error("WALLPAPER_FAIL: " + message); Qt.exit(1); } }
  function commit() {
    const t = service.transaction;
    if (t) for (const name of t.waiting) service.prepared(name, t.serial);
  }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      root.check(++root.ticks < 180, "operations timeout " + root.stage);
      if (!service.ready || service.scanning || service.remoteBusy) return;
      if (root.stage === 0) {
        service.screens = [{name: "A", x: 0, y: 0, width: 800, height: 600}];
        root.stage = 1;
      } else if (root.stage === 1) {
        root.commit(); root.before = service.activePaths.A; root.serialBefore = service.serial;
        service.rotate(); root.check(!service.transaction && service.serial === root.serialBefore, "rotation disabled rejects start");
        service.update("rotation", true); service.rotate();
        root.check(!!service.transaction, "rotation starts when enabled");
        const stale = service.transaction.serial;
        service.update("rotation", false);
        root.check(!service.transaction && service.activePaths.A === root.before, "disable cancels loading rotation");
        service.prepared("A", stale);
        root.check(service.activePaths.A === root.before, "late readiness cannot commit cancelled rotation");
        root.serialBefore = service.serial;
        service.refresh(); root.stage = 2;
      } else if (root.stage === 2) {
        root.check(!service.transaction && service.serial === root.serialBefore && service.activePaths.A === root.before, "refresh preserves wallpaper");
        service.assign(root.library + "/light/light.png", "light", "A", "Per monitor");
        root.check(service.collection === "light" && !!service.transaction, "assignment switches collection and starts applying");
        root.commit();
        root.check(service.activePaths.A.endsWith("light.png"), "assignment applies the chosen wallpaper");
        service.assign(root.library + "/still.webp", "light", "A", "Span");
        root.commit();
        root.check(service.activePaths.A.endsWith("still.webp") && service.state.layout === "Span", "layout assignment applies");
        service.assign(root.library + "/light/light.png", "light", "DISCONNECTED", "Per monitor");
        root.commit();
        root.check(service.state.selections.light.monitors.DISCONNECTED.endsWith("light.png"), "disconnected assignment retained");
        root.check(service.activePaths.A.endsWith("light.png"), "per-monitor assignment applies to the known monitor");
        service.setTheme("Dark"); root.commit();
        root.check(service.collection === "dark", "theme switch returns to the dark collection");
        service.setTheme("Light"); root.commit();
        root.check(service.collection === "light" && service.activePaths.A.endsWith("light.png"), "theme switch restores the active collection assignment");
        preferences.value = {mode: "dark", animations: false}; root.commit();
        service.apply(root.library + "/missing-test.png", "A"); root.commit();
        root.before = service.activePaths.A; root.serialBefore = service.serial;
        move.running = true; root.stage = 3;
      } else if (root.stage === 3) {
        if (move.running) return;
        service.refresh(); root.stage = 4;
      } else if (root.stage === 4) {
        root.check(service.activePaths.A === root.before && !service.transaction && service.serial === root.serialBefore && service.warning.length > 0, "missing active file warns without replacement");
        service.download({path: "https://w.wallhaven.cc/full/ab/wallhaven-abc123.png"}, "light", "A", "assign", "light", "Per monitor");
        service.setTheme("Dark"); root.commit();
        service.setTheme("Light"); root.commit();
        root.stage = 5;
      } else if (root.stage === 5) {
        root.check(service.notice.includes("destination changed") && !service.pendingDownloadApply, "context changed and returned rejects obsolete assignment");
        root.check(!service.state.selections.light.monitors.A.includes("wallhaven"), "download saved without obsolete assignment");
        root.before = service.activePaths.A;
        service.download({path: "https://w.wallhaven.cc/full/ab/wallhaven-abc123.png"}, "shared", "A", "manual", "dark", "Per monitor");
        service.invalidateDownloadTarget(); root.stage = 6;
      } else if (root.stage === 6) {
        root.check(service.activePaths.A === root.before && service.notice.includes("destination changed"), "editing the dialog destination prevents obsolete application");
        const saved = JSON.stringify(service.state);
        service.assign(root.library + "/broken.png", service.collection, "A", "Mirror");
        service.failed("A", service.transaction.serial, "simulated decoder failure");
        root.check(JSON.stringify(service.state) === saved && service.activePaths.A === root.before, "failed assignment preserves persisted selections and layout");
        const candidate = service.available.find(e => e.path !== root.before);
        service.apply(candidate.path, "A", "Mirror");
        const pending = service.transaction.serial;
        service.screens = [];
        root.check(!service.transaction, "monitor change cancels pending load");
        service.prepared("A", pending);
        root.check(service.activePaths.A === root.before, "late monitor readiness cannot commit obsolete wallpaper");
        console.log("WALLPAPER_OPERATIONS_PASS (rotation cancellation, refresh, assignment, theme switching, layouts, missing file, stale download)"); Qt.quit();
      }
    }
  }
  Process {
    id: move
    command: ["mv", root.library + "/missing-test.png", root.library + "/missing-test.moved"]
  }
}
