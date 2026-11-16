import QtQuick
import QtQuick.Window
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/common" as Settings
import "../../config/quickshell/common" as Design

Scope {
  id: root
  property int stage: 0
  property int ticks: 0
  property bool closedByView: false
  readonly property string library: Quickshell.env("HOME") + "/Pictures/Wallpapers"
  function check(ok, message) { if (!ok) { console.error("WALLPAPER_FAIL: " + message); Qt.exit(1); } }
  function commit() {
    const t = service.transaction;
    if (t) for (const name of t.waiting) service.prepared(name, t.serial);
  }
  QtObject { id: preferences; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: preferences }
  Wallpaper.WallpaperService { id: service; settings: preferences; blocked: false; screens: [] }
  Window {
    id: testWindow
    visible: true; width: 1280; height: 800
    Wallpaper.WallpaperCarouselView {
      id: view
      anchors.fill: parent
      service: service
      tokens: theme
      monitorName: "A"
      onCloseRequested: root.closedByView = true
    }
  }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      root.check(++root.ticks < 200, "carousel timeout stage " + root.stage);
      if (!service.ready || service.scanning) return;
      if (service.transaction) { root.commit(); return; }
      if (root.stage === 0) {
        service.screens = [{name: "A", x: 0, y: 0, width: 1280, height: 800}];
        root.stage = 1;
      } else if (root.stage === 1) {
        if (!view.items.length) return;
        view.active = true;
        root.stage = 2;
      } else if (root.stage === 2) {
        const active = view.items.findIndex(e => e.path === service.activePaths.A);
        const count = view.items.length;
        root.check(active >= 0 && view.currentIndex === active, "carousel starts on the active wallpaper");
        root.check(count > 2, "carousel needs several wallpapers to exercise wrapping");
        view.currentIndex = count - 1;
        view.move(1);
        root.check(view.currentIndex === 0, "moving past the last wallpaper wraps to the first");
        view.move(-1);
        root.check(view.currentIndex === count - 1, "moving before the first wallpaper wraps to the last");
        view.currentIndex = active;
        view.move(1);
        root.check(view.currentIndex === (active + 1) % count, "right moves to the next wallpaper");
        view.move(count);
        root.check(view.currentIndex === (active + 1) % count, "a full turn returns to the same wallpaper");
        view.move(-1);
        root.check(view.currentIndex === active, "left moves to the previous wallpaper");
        const target = view.items.findIndex(e => e.name === "00 first.png");
        root.check(target >= 0, "shared wallpapers are listed");
        view.currentIndex = target;
        view.applyCurrent();
        root.check(!!service.transaction, "enter starts applying the centered wallpaper");
        root.commit();
        root.check(service.activePaths.A === view.items[target].path, "enter applies the centered wallpaper");
        root.check(root.closedByView, "applying closes the carousel");
        console.log("WALLPAPER_CAROUSEL_PASS (active item, navigation, wrap, apply, close)");
        Qt.quit();
      }
    }
  }
}
