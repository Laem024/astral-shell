import QtQuick
import Quickshell
import Quickshell.Io
import "../../config/quickshell/astral-clipboard" as Clipboard
import "../../config/quickshell/astral-clipboard/Logic.js" as Logic
import "../../config/quickshell/common" as Common
ShellRoot {
  id: root
  readonly property string fixture: Quickshell.env("ASTRAL_FIXTURE")
  property int stage: 0
  property int ticks: 0
  property int entered: 0
  property int copies: 0
  property string firstId: ""
  property string imagePath: ""
  QtObject { id: preferences; property var value: ({historySize: 2, maxImageBytes: 100, enterAction:"paste",pasteShortcut:{mods:"CTRL",key:"v"}}) }
  Clipboard.ClipboardService { id: service; settings: preferences; onCopied: root.copies++ }
  FileView { id: file; blockLoading: true; blockWrites: true; atomicWrites: true; printErrors: false }
  function write(name, text) { file.path = fixture + "/" + name; file.setText(text); file.waitForJob(); }
  function read(path) { file.path = path; file.reload(); file.waitForJob(); return file.text(); }
  function check(ok, message) { if (!ok) { console.error("CLIPBOARD_SERVICE_FAIL: " + message); Qt.exit(1); } }
  function advance() { stage++; entered = ticks; }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      root.ticks++;
      root.check(root.ticks < 500, "stage timed out " + root.stage + ": " + service.error);
      if (!service.ready || !Common.Privacy.ready || service.busy || service.queue.length) return;
      if (Quickshell.env("ASTRAL_CORRUPT") && root.stage < 2) {
        if (root.stage === 0) {
          root.check(service.corrupt, "corrupt history detected");
          root.check(root.read(service.dir + "/history.json") === "{broken history", "corrupt bytes retained");
          service.clear(); root.advance(); return;
        }
        root.check(!service.corrupt && service.items.length === 0, "explicit clear recovers corruption");
        console.log("CLIPBOARD_CORRUPT_PASS"); Qt.quit(); return;
      }
      switch (root.stage) {
      case 0:
        if (Common.Privacy.blocked) return;
        root.write("types", "text/plain;charset=utf-8\n"); root.write("kind", "text"); root.write("input", "hello\nworld\n\n");
        service.enqueue("capture"); root.advance(); break;
      case 1:
        root.check(service.items.length === 1 && service.items[0].text === "hello\nworld\n\n", "multiline and trailing newlines");
        root.firstId = service.items[0].id; service.enqueue("capture"); service.trim(); root.advance(); break;
      case 2:
        root.check(service.items.length === 1 && service.items[0].id === root.firstId, "dedupe and serial queue");
        root.write("types", "image/png\ntext/plain\n"); root.write("kind", "image"); service.enqueue("capture"); root.advance(); break;
      case 3: {
        root.check(service.items.length === 2 && service.items[0].kind === "image" && service.items[0].bytes === 8, "image metadata");
        root.imagePath = service.dir + "/" + service.items[0].file;
        file.path = root.imagePath; file.reload(); file.waitForJob();
        const bytes = new Uint8Array(file.data());
        root.check(Array.from(bytes).join(",") === "137,80,78,71,0,255,128,10", "exact binary bytes including NUL and non-UTF8");
        service.copy(service.items[0]); root.advance(); break;
      }
      case 4:
        root.check(root.copies === 1, "copy confirmation");
        root.check(root.read(root.fixture + "/copy-args").includes("--foreground"), "foreground owner");
        root.write("types", "text/plain\nx-kde-passwordManagerHint\n"); service.enqueue("capture"); root.advance(); break;
      case 5:
        root.check(service.items.length === 2, "sensitive MIME ignored");
        preferences.value = Object.assign({}, preferences.value, {maxImageBytes: 4});
        root.write("types", "image/png\n"); service.enqueue("capture"); root.advance(); break;
      case 6:
        root.check(service.warning.includes("maxImageBytes"), "image size limit");
        preferences.value = Object.assign({}, preferences.value, {historySize: 1}); service.trim(); root.advance(); break;
      case 7:
        root.check(service.items.length === 1 && service.items[0].kind === "image", "history limit keeps newest");
        service.remove(service.items[0].id); root.advance(); break;
      case 8:
        root.check(service.items.length === 0, "remove serialized");
        // Capture waits in wl-paste while the privacy probe sees a lock.
        root.write("delay", "yes"); root.write("types", "text/plain\n");
        service.enqueue("capture"); lockDelay.restart(); root.advance(); break;
      case 9:
        if (!Common.Privacy.blocked) return;
        root.check(service.items.length === 0 && !service.watching, "lock cancels pending capture and watcher");
        root.write("locked", "no"); root.advance(); break;
      case 10:
        if (Common.Privacy.blocked || !service.watching || root.ticks - root.entered < 20) return;
        root.check(service.items.length === 0, "unlock does not import retained selection");
        root.write("state/astral-shell/astral-clipboard/history.json", "{runtime corrupt");
        service.trim(); root.advance(); break;
      case 11:
        root.check(service.corrupt && root.read(service.dir + "/history.json") === "{runtime corrupt", "runtime corruption is retained");
        service.clear(); root.advance(); break;
      case 12:
        root.check(!service.corrupt, "explicit clear recovers runtime corruption");
        root.write("locked", "unknown"); root.advance(); break;
      case 13:
        if (!Common.Privacy.blocked) return;
        root.check(!service.watching, "unknown privacy fails closed");
        console.log("CLIPBOARD_SERVICE_PASS"); Qt.quit(); break;
      }
    }
  }
  Timer { id: lockDelay; interval: 100; onTriggered: root.write("locked", "yes") }
}
