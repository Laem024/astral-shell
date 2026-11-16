import QtQuick
import Quickshell
import "../../config/quickshell/astral-overview/Logic.js" as Logic
import "../../config/quickshell/common" as Settings
import "../../config/quickshell/common/Validation.js" as SettingsLogic

Scope {
  id: root
  property bool checked: false
  function check(ok, message) { if (!ok) { console.error("OVERVIEW_FAIL: " + message); Qt.exit(1); } }
  function run() {
    root.check(Logic.count(10) === 10, "workspace count");
    root.check(Logic.count(0) === 10 && Logic.count(101) === 10, "invalid counts fall back to 10");
    root.check(Logic.blockStart(1, 10) === 0, "first block");
    root.check(Logic.blockStart(10, 10) === 0, "last workspace of the first block");
    root.check(Logic.blockStart(11, 10) === 10, "second block starts at 11");
    root.check(Logic.blockStart(21, 10) === 20, "third block starts at 21");
    root.check(Logic.blockIds(11, 10)[0] === 11 && Logic.blockIds(11, 10)[9] === 20,
      "block identifiers");
    root.check(Logic.blockIds(6, 5)[0] === 6 && Logic.blockIds(6, 5)[4] === 10,
      "five-slot block");

    const windows = [
      { title: "third", lastIpcObject: { focusHistoryID: 3 } },
      { title: "first", lastIpcObject: { focusHistoryID: 0 } },
      { title: "second", lastIpcObject: { focusHistoryID: 1 } },
      { title: "never", lastIpcObject: {} }
    ];
    root.check(Logic.sortWindows(windows).map(window => window.title).join(",")
      === "first,second,third,never", "windows follow focus history");

    root.check(Logic.direction("previous") === -1 && Logic.direction("next") === 1,
      "direction names");
    root.check(Logic.direction(0) === 0 && Logic.direction("active") === 0,
      "opening keeps the active workspace");
    root.check(Logic.wrap(-1, 5) === 4 && Logic.wrap(5, 5) === 0, "wrapping selection");
    const rects = [
      { id: 1, x: 0, y: 0, width: 100, height: 100 },
      { id: 2, x: 110, y: 0, width: 100, height: 100 }
    ];
    root.check(Logic.dropTarget({ x: 50, y: 50 }, rects, 0) === 1, "drop target");
    root.check(Logic.dropTarget({ x: 150, y: 50 }, rects, 1) === 2, "drop target by position");
    root.check(Logic.dropTarget({ x: 150, y: 50 }, rects, 2) === -1, "same workspace is not a drop");
    root.check(Logic.dropTarget({ x: 50, y: 150 }, rects, 1) === -1, "outside cards");
    root.check(Logic.dropTarget({ x: 50, y: 50 }, [], 1) === -1, "empty cards");

    root.check(Logic.activeWorkspaceIndex([1, 2, 3], 2, 1) === 2, "selection follows workspaces");
    root.check(Logic.activeWorkspaceIndex([1, 2, 3], 2, -1) === 0, "selection goes back");
    root.check(Logic.activeWorkspaceIndex([11, 12, 13], 11, -1) === 2, "selection wraps");
    root.check(Logic.activeWorkspaceIndex([1, 2], 99, 1) === 0, "missing active workspace");
    root.check(Logic.activeWorkspaceIndex([], 1, 1) === -1, "empty workspace list");
    root.check(Logic.luaString('a"b') === '"a\\"b"', "Lua strings are escaped");
    root.check(Logic.windowAddress({ address: "0xabc" }) === "0xabc", "window address");
    root.check(Logic.windowAddress("ABC") === "0xabc", "addresses without 0x are normalized");
    root.check(Logic.windowAddress({ address: "xyz" }) === "", "invalid addresses are rejected");
    root.check(Logic.windowAppId({ appId: "kitty" }) === "kitty", "window app id");
    root.check(Logic.windowTitle({ title: "Terminal" }) === "Terminal", "window title");

    root.check(Logic.moveCommand("0xABC", 3, true)
      === 'hl.dsp.window.move({ window = "address:0xabc", workspace = 3, follow = false })',
      "lua move command");
    root.check(Logic.moveCommand("ABC", 12, false) === "movetoworkspacesilent 12,address:0xabc",
      "legacy move command");
    root.check(Logic.moveCommand("", 3, true) === "" && Logic.moveCommand("0xabc", 0, true) === ""
      && Logic.moveCommand("0xabc", "x", false) === "", "invalid moves are rejected");
    root.check(Logic.moveWorkspaceCommand(3, "DP-1", true)
      === 'hl.dsp.workspace.move({ workspace = 3, monitor = "DP-1" })',
      "lua workspace monitor move");
    root.check(Logic.moveWorkspaceCommand(12, "eDP-1", false)
      === "moveworkspacetomonitor 12 eDP-1", "legacy workspace monitor move");
    root.check(Logic.moveWorkspaceCommand(0, "DP-1", true) === ""
      && Logic.moveWorkspaceCommand(3, "", true) === ""
      && Logic.moveWorkspaceCommand(3, "  ", false) === "",
      "invalid workspace monitor moves are rejected");

    root.check(Settings.SettingsData.value.overview.previews === true, "overview settings load");
    const clone = value => JSON.parse(JSON.stringify(value));
    const bad = clone(Settings.SettingsData.value);
    bad.overview.previews = "yes";
    let rejected = false;
    try { SettingsLogic.parse(JSON.stringify(bad), "common"); } catch (_) { rejected = true; }
    root.check(rejected, "invalid previews value is rejected");

    console.log("OVERVIEW_QML_PASS (blocks, ordering, wrapping, moves, monitors, settings)");
    Qt.quit();
  }
  Timer {
    interval: 100
    running: !root.checked
    onTriggered: { root.checked = true; root.run(); }
  }
}
