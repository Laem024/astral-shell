import QtQuick
import Quickshell
import Quickshell.Io
import "../../config/quickshell/astral-shortcuts" as Shortcuts
import "../../config/quickshell/astral-shortcuts/Logic.js" as Logic
import "../../config/quickshell/astral-shortcuts/data" as Data
import "../../config/quickshell/common" as Settings
import "../../config/quickshell/common/Validation.js" as SettingsLogic
import "../../config/quickshell/common" as Design

ShellRoot {
  id: root
  property bool checked: false
  property bool contentChecked: false
  property int ticks: 0
  function check(ok, message) { if (!ok) { console.error("SHORTCUTS_FAIL: " + message); Qt.exit(1); } }

  FileView {
    id: fixture
    blockLoading: true
    path: Quickshell.env("ASTRAL_SHORTCUTS_FIXTURE")
  }

  QtObject { id: config; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: config }
  Shortcuts.ShortcutsContent {
    id: content
    tokens: theme
    active: true
    width: 900
    height: 600
  }

  Component.onCompleted: {
    root.check(Logic.splitDescription("Windows · Focus left").category === "Windows", "description category");
    root.check(Logic.splitDescription("Windows · Focus left").label === "Focus left", "description label");
    root.check(Logic.splitDescription("Uncategorized").category === "Other", "missing category falls back to Other");
    root.check(Logic.formatKeys({ modmask: 65, key: "Tab" }).join("+") === "Super+Shift+Tab", "modmask formatting");
    root.check(Logic.formatKeys({ modmask: 72, key: "left" }).join("+") === "Super+Alt+←", "arrow formatting");
    root.check(Logic.formatKeys({ modmask: 0, key: "XF86AudioMute" }).join("+") === "Mute", "media key formatting");
    root.check(Logic.formatKeys({ modmask: 64, key: "mouse:272" }).join("+") === "Super+Left click", "mouse formatting");
    root.check(Logic.formatKeys({ modmask: 64, key: "RETURN" }).join("+") === "Super+Enter", "uppercase named key formatting");
    root.check(Logic.clampIndex(-1, 4) === 0 && Logic.clampIndex(9, 4) === 3, "category index clamp");

    const parsed = Logic.parseBinds(fixture.text());
    root.check(parsed.error === "" && parsed.total === 8, "fixture bindings are parsed");
    root.check(parsed.categories.map(category => category.name).join(",") === "Apps,Astral,Windows,Media,Mouse,Custom,Other",
      "categories follow the configured order");
    const apps = parsed.categories[0];
    root.check(apps.entries.length === 1 && apps.entries[0].label === "Terminal"
      && apps.entries[0].keys.join("+") === "Super+Enter", "apps category content");
    const windows = parsed.categories[2];
    root.check(windows.entries.length === 2, "windows category content");
    root.check(windows.entries[1].keys.join("+") === "Super+Alt+←", "resize keys");
    const other = parsed.categories[parsed.categories.length - 1];
    root.check(other.entries.length === 1 && other.entries[0].label === "exec cmd", "unlabeled bindings fall under Other");
    root.check(parsed.categories.every(category => category.entries.every(entry => entry.label !== "Disabled")),
      "disabled bindings are filtered");

    root.check(parsed.categories.every(category => {
      const code = category.glyph.charCodeAt(0);
      return code >= 0xe000 && code <= 0xf8ff;
    }), "category glyphs use the Nerd Font");
    const rail = Logic.railFor(parsed.categories, parsed.total);
    root.check(rail.length === 8 && rail[0].name === "All" && rail[0].count === 8, "rail totals");
    root.check(rail[0].glyph.charCodeAt(0) >= 0xe000, "all glyph uses the Nerd Font");
    root.check(Logic.rowsFor(parsed.categories, "All").length === 15, "all rows");
    root.check(Logic.rowsFor(parsed.categories, "Media").length === 2, "filtered rows");

    const searched = Logic.filterCategories(parsed.categories, "resize", []);
    root.check(searched.length === 1 && searched[0].name === "Windows"
      && searched[0].entries.length === 1, "search filters entries");
    root.check(Logic.countEntries(searched) === 1, "search total");
    root.check(Logic.countEntries(Logic.filterCategories(parsed.categories, "super+shift", [])) === 1,
      "search accepts joined chords");
    root.check(Logic.filterCategories(parsed.categories, "nothing here", []).length === 0,
      "empty search drops every category");
    const shifted = Logic.filterCategories(parsed.categories, "", ["Shift"]);
    root.check(Logic.countEntries(shifted) === 1
      && shifted[0].entries[0].keys.indexOf("Shift") >= 0, "modifier filter");
    const split = Logic.splitColumns(parsed.categories);
    root.check(split.left.length + split.right.length === parsed.categories.length,
      "masonry keeps every category");

    root.check(config.value.mode === "dark" && config.value.scale === 1 && config.value.animations === true,
      "shortcuts settings load");
    let rejected = false;
    try { SettingsLogic.parse('{"mode":"auto"}'); } catch (_) { rejected = true; }
    root.check(rejected, "invalid settings are rejected");
    rejected = false;
    const bad = JSON.parse(JSON.stringify(config.value));
    bad.scale = 0;
    try { SettingsLogic.parse(JSON.stringify(bad), "common"); } catch (_) { rejected = true; }
    root.check(rejected, "invalid scale is rejected");
  }

  Timer {
    interval: 50
    repeat: true
    running: true
    onTriggered: {
      root.ticks++;
      root.check(root.ticks < 120, "shortcuts timeout");
      if (!root.checked) {
        root.checked = true;
        Data.ShortcutsData.refresh();
        return;
      }
      if (Data.ShortcutsData.loading || Data.ShortcutsData.categories.length === 0) return;
      if (!root.contentChecked) {
        root.contentChecked = true;
        root.check(Data.ShortcutsData.total === 8, "ShortcutsData total");
        root.check(Data.ShortcutsData.error === "", "ShortcutsData has no error");
        root.check(content.rail.length === 8, "content rail");
        root.check(content.rows.length === 15, "content rows");
        content.select(1);
        root.check(content.selected === "Apps", "category selection");
        root.check(content.rows.length === 2, "selected category rows");
        content.reset();
        root.check(content.categoryIndex === 0 && content.selected === "All", "reset selects all");
        content.query = "resize";
        root.check(content.display.length === 1 && content.display[0].name === "Windows"
          && content.displayTotal === 1 && content.single, "content search view");
        content.select(3);
        root.check(content.selected === "Windows" && content.displayTotal === 1,
          "search stays inside the selected category");
        content.reset();
        content.modifiers = ["Shift"];
        root.check(content.visibleTotal === 1 && content.displayTotal === 1
          && content.filtering, "content modifier view");
        content.reset();
        root.check(!content.filtering && content.rows.length === 15, "content restores all rows");
        console.log("SHORTCUTS_QML_PASS (config, parsing, categories, formatting, rows, search, filters, selection)");
        Qt.quit();
      }
    }
  }
}
