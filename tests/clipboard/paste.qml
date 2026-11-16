import QtQuick
import Quickshell
import Quickshell.Io
import "../../config/quickshell/astral-clipboard" as Clipboard
import "../../config/quickshell/common" as Common
ShellRoot {
  id: root
  property int phase: 0
  property int ticks: 0
  readonly property string fixture: Quickshell.env("ASTRAL_FIXTURE")
  Common.Theme { id: theme; settings: Common.SettingsData }
  QtObject { id: preferences; property var value: Common.SettingsData.value.clipboard }
  QtObject {
    id: sample
    property bool ready: true
    property bool watching: false
    property string error: ""
    property string warning: ""
    property var items: []
    signal copied()
    function source(item) { return ""; }
    function reload() {}
  }
  Clipboard.ClipboardPanel { tokens: theme; settings: preferences; service: sample }
  FileView { id: file; blockWrites: true; blockLoading: true; printErrors: false }
  function write(value) { file.path = fixture + "/locked"; file.setText(value); file.waitForJob(); }
  function pasted() { file.path = fixture + "/pasted"; file.reload(); file.waitForJob(); return file.text(); }
  function check(ok, message) { if (!ok) { console.error("CLIPBOARD_PASTE_FAIL: " + message); Qt.exit(1); } }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      root.check(++root.ticks < 120, "paste test timed out");
      if (!Common.Privacy.ready) return;
      if (root.phase === 0 && !Common.Privacy.blocked) {
        sample.copied(); root.write("yes"); root.phase = 1; root.ticks = 0;
      } else if (root.phase === 1 && root.ticks > 20) {
        root.check(root.pasted() === "", "lock during close animation prevents paste");
        root.write("no"); root.phase = 2;
      } else if (root.phase === 2 && !Common.Privacy.blocked) {
        sample.copied(); root.phase = 3;
      } else if (root.phase === 3 && root.pasted() !== "") {
        root.check(root.pasted().includes("send_shortcut"), "unlocked paste uses literal Hyprland shortcut");
        console.log("CLIPBOARD_PASTE_PASS"); Qt.quit();
      }
    }
  }
}
