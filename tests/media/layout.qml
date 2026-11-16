import QtQuick
import QtQuick.Window
import Quickshell
import "../../config/quickshell/astral-bar" as Bar
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/modules" as Modules
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design

Scope {
  id: root
  property int stage: 0
  readonly property var widths: [1920, 1600, 1440, 1280, 1100, 2560, 1920]
  QtObject { id: settings; property var value: Settings.SettingsData.value; Component.onCompleted: value = Object.assign({}, value, {animations: false}) }
  Design.Theme { id: theme; settings: settings }
  Panel.PanelState { id: navigation }
  Window {
    visible: true; width: 2560; height: 100
    Bar.BarContent {
      id: bar
      width: root.widths[root.stage]; height: 64
      settings: settings; tokens: theme; navigation: navigation
    }
    Modules.Workspaces {
      id: horizontalSpaces
      tokens: theme
      count: 3; active: root.stage % 3 + 1
      compact: root.stage % 2 === 1
      spaces: [{id: 1}, {id: 2}, {id: 3}]
      specials: []
      x: 2200; width: implicitWidth; height: implicitHeight
    }
    Modules.Workspaces {
      id: verticalSpaces
      tokens: theme
      vertical: true
      count: 3; active: root.stage % 3 + 1
      compact: root.stage % 2 === 1
      spaces: [{id: 1}, {id: 2}, {id: 3}]
      specials: []
      x: 2500; width: implicitWidth; height: implicitHeight
    }
  }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) {
      const match = find(child, name);
      if (match) return match;
    }
    return null;
  }
  Timer {
    id: layoutChecks
    interval: 350; running: true; repeat: true
    onTriggered: {
      const viewport = root.find(bar, "moduleViewport");
      const music = root.find(bar, "music");
      console.log("MEDIA_LAYOUT", bar.width, viewport.width, viewport.contentWidth, music.width, music.compact);
      if (viewport.contentWidth > viewport.width + 1) {
        console.log("MEDIA_LAYOUT_FAIL", "Horizontal overflow at", bar.width);
        Qt.quit(); return;
      }
      const workspaces = root.find(bar, "workspaces");
      for (const strip of [horizontalSpaces, verticalSpaces]) {
        const icon = root.find(strip, "workspaceIcon-" + (strip.active - 1));
        const selection = root.find(strip, "workspaceSelection");
        const iconCenter = icon.mapToItem(strip, icon.width / 2, icon.height / 2);
        const selectionCenter = selection.mapToItem(strip, selection.width / 2, selection.height / 2);
        if (Math.abs(iconCenter.x - selectionCenter.x) > 0.5 || Math.abs(iconCenter.y - selectionCenter.y) > 0.5) {
          console.log("MEDIA_LAYOUT_FAIL", "Workspace icon is off center", strip.vertical);
          Qt.quit(); return;
        }
        const special = root.find(root.find(strip, "workspace-special"), "specialWorkspacePlus");
        const specialCenter = special.mapToItem(strip, special.width / 2, special.height / 2);
        if (Math.abs(strip.vertical ? specialCenter.x - iconCenter.x : specialCenter.y - iconCenter.y) > 0.5) {
          console.log("MEDIA_LAYOUT_FAIL", "Regular and special workspace icons are misaligned");
          Qt.quit(); return;
        }
      }
      const center = workspaces.mapToItem(bar, workspaces.width / 2, 0).x;
      if (Math.abs(center - bar.width / 2) > 1) {
        console.log("MEDIA_LAYOUT_FAIL", "Workspaces lost center alignment", center, bar.width);
        Qt.quit(); return;
      }
      let previousEnd = -1;
      for (const name of ["music", "recordingIndicator", "tray", "network", "audio", "battery", "notifications"]) {
        const item = root.find(bar, name);
        if (!item || !item.visible) continue;
        const left = item.mapToItem(bar, 0, 0).x;
        const right = item.mapToItem(bar, item.width, 0).x;
        const minimum = name === "music" ? 124 : item.implicitWidth;
        if (item.width < minimum - 1 || left < previousEnd - 1 || right > bar.width - theme.inset + 1) {
          console.log("MEDIA_LAYOUT_FAIL", "Module clipped or overlapping", name, item.width, left, right);
          Qt.quit(); return;
        }
        previousEnd = right;
      }
      const capture = root.find(bar, "recordingIndicator");
      const instrument = root.find(capture, "captureInstrument");
      const captureCenter = instrument.mapToItem(bar, instrument.width / 2, instrument.height / 2);
      const glyph = root.find(capture, "captureGlyph");
      const glyphCenter = glyph.mapToItem(bar, 12, 12);
      if (glyph.width !== 24 || glyph.height !== 24 || Math.abs(glyphCenter.x - captureCenter.x) > 0.5 || Math.abs(glyphCenter.y - captureCenter.y) > 0.5) {
        console.log("MEDIA_LAYOUT_FAIL", "Capture path canvas is off center"); Qt.quit(); return;
      }
      const playerCenter = music.mapToItem(bar, music.width / 2, music.height / 2);
      if (Math.abs(captureCenter.y - playerCenter.y) > 0.5) { console.log("MEDIA_LAYOUT_FAIL", "Capture and player baselines differ"); Qt.quit(); return; }
      const clock = root.find(bar, "clock");
      const clockCenter = clock.mapToItem(bar, clock.width / 2, 0).x;
      const clockTime = root.find(clock, "clockTimeRow");
      const clockDate = root.find(clock, "clockDate");
      for (const item of [clockTime, clockDate]) {
        const center = item.mapToItem(bar, item.width / 2, 0).x;
        if (Math.abs(center - clockCenter) > 0.5) {
          console.log("MEDIA_LAYOUT_FAIL", "Clock label is off center", center, clockCenter);
          Qt.quit(); return;
        }
      }
      if (clock.width < Math.max(clockTime.width, clockDate.implicitWidth) + 2 * clock.horizontalPadding - 1) {
        console.log("MEDIA_LAYOUT_FAIL", "Clock lost its symmetric padding");
        Qt.quit(); return;
      }
      const artist = root.find(music, "barMediaArtist");
      if (!music.compact && (!artist.visible || artist.font.pixelSize < 11)) {
        console.log("MEDIA_LAYOUT_FAIL", "Artist readability regressed"); Qt.quit(); return;
      }
      if (root.stage + 1 === root.widths.length) {
        layoutChecks.stop();
        console.log("MEDIA_LAYOUT_PASS");
        const snapshot = Quickshell.env("ASTRAL_BAR_SCREENSHOT");
        if (snapshot) bar.grabToImage(result => { result.saveToFile(snapshot); Qt.quit(); }); else Qt.quit();
      } else root.stage++;
    }
  }
}
