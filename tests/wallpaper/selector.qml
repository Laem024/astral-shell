import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper
import "../../config/quickshell/common" as Settings
import "../../config/quickshell/common" as Design

Scope {
  id: root
  property int stage: 0
  property int ticks: 0
  readonly property string library: Quickshell.env("HOME") + "/Pictures/Wallpapers"
  function findItem(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) { const found = findItem(child, name); if (found) return found; }
    return null;
  }
  function check(value, message) { if (!value) { console.error("WALLPAPER_FAIL: " + message); Qt.exit(1); } }
  QtObject { id: preferences; property var value: Settings.SettingsData.value }
  TestCase { id: pointer; when: false }
  Design.Theme { id: theme; settings: preferences }
  Wallpaper.WallpaperService { id: controller; settings: preferences; blocked: false; screens: [] }
  Window {
    id: testWindow
    visible: true; width: Number(Quickshell.env("ASTRAL_TEST_WIDTH")) || 1280; height: Number(Quickshell.env("ASTRAL_TEST_HEIGHT")) || 800
    Item {
      anchors.centerIn: parent
      width: parent.width / theme.scale; height: parent.height / theme.scale; scale: theme.scale
      Wallpaper.WallpaperContent { id: content; anchors.fill: parent; service: controller; tokens: theme }
    }
    Wallpaper.Thumbnail { id: still; visible: false; service: controller; path: root.library + "/00 first.png" }
    Wallpaper.Thumbnail { id: video; visible: false; service: controller; path: root.library + "/motion.mp4" }
  }
  Component.onCompleted: preferences.value = Object.assign({}, preferences.value, {scale: Number(Quickshell.env("ASTRAL_TEST_SCALE")) || 1, mode: Quickshell.env("ASTRAL_TEST_THEME") || "dark"})
  Timer {
    interval: 80; repeat: true; running: true
    onTriggered: {
      root.check(++root.ticks < 200, "selector timeout stage " + root.stage);
      if (!controller.ready || controller.scanning || controller.remoteBusy) return;
      if (root.stage === 0) {
        root.check(controller.state.folder === root.library, "plural default library");
        if (still.status !== Image.Ready || !video.requestedPath) return;
        root.check(still.requestedPath === "" && decodeURIComponent(still.source.toString()) === "file://" + still.path, "static thumbnails load directly without helper");
        root.check(content.activeTheme === (controller.collection === "light" ? "Light" : "Dark"), "library follows the active mode");
        root.check(content.items.every(e => e.theme === "shared" || e.theme === controller.collection), "library lists only the active mode and shared");
        root.check(content.items.some(e => e.theme === controller.collection) && content.items.some(e => e.theme === "shared"), "active mode and shared entries are present");
        video.path = root.library + "/motion.webm";
        const index = content.items.findIndex(e => e.name === "00 first.png");
        const card = root.findItem(testWindow.contentItem, "wallpaperTile_" + index);
        root.check(!!card, "clickable card exists");
        root.stage = -1; // QtTest may process timer events during the click.
        pointer.mouseClick(card, 10, 10);
        root.check(content.selected.name === "00 first.png", "card selection");
        root.check(content.previewEntry && content.previewEntry.path === content.selected.path && content.confirmationOpen, "popup shows only selected wallpaper");
        root.check(!controller.transaction && Object.keys(controller.activePaths).length === 0, "browsing never applies wallpaper");
        content.dismissConfirmation();
        root.stage = 1;
      } else if (root.stage === 1) {
        if (video.requestedPath !== video.path || video.status !== Image.Ready) return;
        root.check(!video.failed && video.thumbnail.length > 0, "video thumbnail follows latest path after in-flight change");
        content.searchText = "no matching wallpaper";
        root.check(content.items.length === 0 && !content.selected && !content.previewEntry, "filter clears stale selection and preview");
        content.searchText = "";
        content.tab = "Wallhaven";
        controller.search("landscape", 2); root.stage = 2;
      } else if (root.stage === 2) {
        root.check(content.items.length === 1 && !content.selected, "Wallhaven results populate mosaic without selecting");
        root.check(!content.previewEntry && !content.confirmationOpen, "remote browsing does not preview or open confirmation");
        content.choose(0);
        root.check(content.selected.id === "abc123" && !controller.transaction, "remote selection does not apply");
        root.check(content.downloadTarget === "mode" && content.downloadCollection === controller.collection, "Wallhaven defaults to the current mode");
        content.downloadTarget = "shared";
        root.check(content.downloadCollection === "shared", "Wallhaven can download shared");
        content.downloadTarget = "mode";
        content.tab = "Local";
        root.check(!content.selected && !content.confirmationOpen, "source switch clears preview");
        content.choose(content.items.findIndex(e => e.name === "00 first.png"));
        root.stage = 3;
      } else if (root.stage === 3) {
        const actions = root.findItem(testWindow.contentItem, "wallpaperActions");
        root.check(!!actions, "confirmation actions exist");
        const labels = [];
        for (const child of actions.children) if (typeof child.text === "string") labels.push(child.text);
        root.check(!labels.some(text => text.startsWith("Assign to ")), "no Light/Dark assignment button");
        const downloadTarget = root.findItem(testWindow.contentItem, "wallpaperDownloadTarget");
        root.check(!!downloadTarget && !downloadTarget.visible, "download destination hidden for local wallpapers");
        const top = actions.mapToItem(testWindow.contentItem, 0, 0);
        const bottom = actions.mapToItem(testWindow.contentItem, actions.width, actions.height);
        root.check(top.x >= 0 && top.y >= 0 && bottom.x <= testWindow.width && bottom.y <= testWindow.height && actions.height > 0, "confirmation actions stay visible at configured scale");
        const capture = Quickshell.env("ASTRAL_WALLPAPER_CAPTURE");
        if (capture) testWindow.contentItem.grabToImage(result => {
          root.check(result.saveToFile(capture), "selector screenshot");
          root.finish();
        });
        else root.finish();
        root.stage = 4;
      }
    }
  }
  function finish() {
    controller.update("folder", library + "/nested");
    root.stage = 5;
    completion.start();
  }
  Timer {
    id: completion
    interval: 80; repeat: true
    onTriggered: {
      if (controller.scanning) return;
      root.check(controller.entries.length === 1 && content.items.length === 1 && content.items[0].name.includes("spaces"), "changing library replaces mosaic");
      root.check(!content.selected && !content.previewEntry, "folder change clears stale selection");
      console.log("WALLPAPER_SELECTOR_PASS (mosaic, local and remote previews, explicit selection, filters, folder change, thumbnail race)");
      Qt.quit();
    }
  }
}
