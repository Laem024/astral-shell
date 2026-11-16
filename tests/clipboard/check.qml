import QtQuick
import Quickshell
import "../../config/quickshell/astral-clipboard/Logic.js" as Logic
import "../../config/quickshell/common" as Settings
import "../../config/quickshell/common/Validation.js" as SettingsLogic

Scope {
  id: root
  property bool checked: false
  function check(ok, message) { if (!ok) { console.error("CLIPBOARD_FAIL: " + message); Qt.exit(1); } }
  function run() {
    const id = "a".repeat(64);
    const parsed = Logic.parseState(JSON.stringify({
      version: 1,
      dir: "/astral-test/state/clipboard",
      items: [
        { id: id, kind: "text", mime: "text/plain", text: "hello\nworld", time: 1000 },
        { id: "b".repeat(64), kind: "image", mime: "image/png", file: "images/" + "b".repeat(64) + ".png", bytes: 2048, time: 2000 }
      ]
    }));
    root.check(parsed.items.length === 2, "valid entries are preserved");
    root.check(parsed.dir === "/astral-test/state/clipboard", "state directory is preserved");
    root.check(Logic.preview(parsed.items[0]) === "hello world", "text preview collapses newlines");
    root.check(Logic.mimeLabel("image/png") === "PNG", "MIME label");
    root.check(Logic.formatBytes(2048) === "2.0 KB", "byte formatting");
    root.check(Logic.relativeTime(1000, 12000) === "11s ago", "relative seconds");
    root.check(Logic.relativeTime(1000, 1000 + 125000) === "2 min ago", "relative minutes");
    root.check(Logic.luaShortcut("CTRL", "v") === 'hl.dsp.send_shortcut({ mods = "CTRL", key = "v" })',
      "Hyprland shortcut expression");
    root.check(Logic.luaShortcut('CTRL"', "v").includes('\\"'), "shortcut values are escaped");
    root.check(Settings.SettingsData.value.clipboard.historySize === 50 && Settings.SettingsData.value.clipboard.enterAction === "paste",
      "clipboard settings load");

    const clone = value => JSON.parse(JSON.stringify(value));
    const rejects = value => {
      try { SettingsLogic.parse(JSON.stringify(value), "common"); return false; } catch (_) { return true; }
    };
    const badLimit = clone(Settings.SettingsData.value); badLimit.clipboard.historySize = 0;
    root.check(rejects(badLimit), "zero history limit is rejected");
    const badAction = clone(Settings.SettingsData.value); badAction.clipboard.enterAction = "send";
    root.check(rejects(badAction), "unknown enter action is rejected");
    const badShortcut = clone(Settings.SettingsData.value); badShortcut.clipboard.pasteShortcut.key = "";
    root.check(rejects(badShortcut), "empty paste key is rejected");
    const badImage = clone(Settings.SettingsData.value); badImage.clipboard.maxImageBytes = 0;
    root.check(rejects(badImage), "zero image limit is rejected");

    root.check(Logic.sha256(new Uint8Array([97,98,99]).buffer) === "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256 reference vector");
    root.check(!Logic.managedImage("images/../secret") && !Logic.managedImage("/outside/image.png"), "unsafe image paths rejected");
    root.check(Logic.chooseMime("text/plain\nx-kde-passwordManagerHint") === "", "sensitive MIME rejected");
    root.check(Logic.chooseMime("text/plain\nimage/png") === "image/png", "images preferred");
    root.check(Logic.specifier("/state/100%/file") === "/state/100%%/file", "systemd specifiers escaped");
    let rejected = false; try { Logic.parseState('{"version":1,"items":[{"id":"broken"}]}'); } catch (_) { rejected = true; }
    root.check(rejected, "corrupt history is rejected as a whole");
    console.log("CLIPBOARD_QML_PASS (state parsing, previews, formatting, shortcut escaping, settings validation)");
    Qt.quit();
  }
  Timer {
    interval: 100
    running: !root.checked
    onTriggered: { root.checked = true; root.run(); }
  }
}
