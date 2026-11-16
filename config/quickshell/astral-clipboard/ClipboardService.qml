import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../common" as Common
import "Logic.js" as Logic

// One queue owns capture, persistence, copy and garbage collection. The lifetime
// lock also prevents two differently named stock entries sharing this store.
Scope {
  id: root
  required property var settings
  readonly property string dir: Common.Paths.state + "/astral-clipboard"
  property var items: []
  property var safeImages: ({})
  property bool ready: false
  property bool corrupt: false
  property bool haveManifest: false
  property string error: ""
  property string warning: ""
  readonly property bool watching: watcher.running
  property var queue: []
  property bool busy: false
  property int epoch: 0
  property int selection: 0
  property bool skipInitial: true
  property var binaryDone: null
  property bool binaryPending: false
  property bool saved: false
  property string ownerUnit: ""
  signal copied()
  signal copyFailed(string message)

  Common.Command { id: command; timeout: 5000 }
  Common.Command { id: watchProbe; timeout: 2000 }
  Common.StartupLock {
    id: storeLock
    key: "clipboard-store"
    onAcquired: root.initialize()
    onFailed: message => { root.error = message; root.ready = true; root.corrupt = true; }
  }
  FileView {
    id: history
    path: root.dir + "/history.json"
    atomicWrites: true; blockWrites: true; blockLoading: true; printErrors: false
    onSaved: root.saved = true
    onSaveFailed: root.saved = false
  }
  FileView {
    id: payload
    atomicWrites: true; blockWrites: true; blockLoading: true; printErrors: false
    onSaved: root.saved = true
    onSaveFailed: root.saved = false
  }
  FolderListModel {
    id: images
    folder: "file://" + root.dir + "/images"
    showDirs: false; showHidden: false
    nameFilters: ["*"]
  }
  function initialize() {
    command.run(["mkdir", "-p", "-m", "700", "--", dir, dir + "/images"], code => {
      if (code !== 0) { fail("Cannot prepare clipboard storage."); ready = true; corrupt = true; return; }
      command.run(["chmod", "700", "--", dir, dir + "/images"], code => {
        if (code !== 0) { fail("Cannot secure clipboard storage."); ready = true; corrupt = true; return; }
        command.run(["test", "-e", dir + "/history.json"], code => {
          if (code === 1) { ready = true; enqueue("clear"); updateWatch(); return; }
          if (code !== 0) { ready = true; corrupt = true; fail("Cannot inspect clipboard history."); return; }
          haveManifest = true;
          history.reload(); history.waitForJob();
          try {
            items = Logic.parseState(history.text()).items;
            validateStoredImages(() => { ready = true; enqueue("trim"); updateWatch(); });
          } catch (_) {
            ready = true; corrupt = true;
            warning = "Clipboard history is corrupt. Back it up, then explicitly clear it to reset.";
          }
        });
      });
    });
  }
  function copyError(message) { error = message; copyFailed(message); }
  function fail(message) { error = message; }
  function allowed(token) { return token === epoch && Common.Privacy.ready && !Common.Privacy.blocked; }
  function enqueue(kind, value) {
    if (!ready) return;
    if (kind === "capture") queue = queue.filter(job => job.kind !== "capture");
    queue = queue.concat([{kind: kind, value: value, epoch: epoch, selection: selection}]);
    Qt.callLater(next);
  }
  function reload() { /* The service is the sole writer; UI observes items. */ }
  function trim() { enqueue("trim"); }
  function remove(id) { if (/^[a-f0-9]{64}$/.test(id)) enqueue("remove", id); }
  function clear() { enqueue("clear"); }
  function copy(item) { if (item && Logic.validItem(item)) enqueue("copy", item.id); }
  function validateStoredImages(complete) {
    const candidates = items.filter(item => item.kind === "image"), trusted = {};
    function inspect(index) {
      if (index >= candidates.length) { safeImages = trusted; complete(); return; }
      const item = candidates[index], path = dir + "/" + item.file;
      command.run(["realpath", "-e", "--", path], (code, output) => {
        if (code === 0 && output.trim() === path) trusted[item.file] = true;
        inspect(index + 1);
      });
    }
    inspect(0);
  }
  function source(item) { return item && item.kind === "image" && safeImages[item.file] && Logic.managedImage(item.file) ? "file://" + dir + "/" + item.file : ""; }
  function done() { busy = false; Qt.callLater(next); }
  function next() {
    if (busy || !queue.length) return;
    const job = queue[0]; queue = queue.slice(1); busy = true;
    if ((corrupt && job.kind !== "clear") || !allowed(job.epoch)) { done(); return; }
    Common.Privacy.check(ok => {
      if (!ok || !allowed(job.epoch)) { done(); return; }
      if (job.kind === "capture") capture(job);
      else if (job.kind === "copy") copyItem(job);
      else {
        const nextItems = job.kind === "clear" ? [] : items.filter(item => job.kind !== "remove" || item.id !== job.value);
        persist(nextItems.slice(0, settings.value.historySize), job, () => {
          if (job.kind === "clear") { corrupt = false; warning = ""; updateWatch(); }
          done();
        });
      }
    });
  }
  function secure(path, done) { command.run(["chmod", "600", "--", path], code => done(code === 0)); }
  function persist(value, job, complete) {
    Common.Privacy.check(ok => {
      if (!ok || !allowed(job.epoch)) { done(); return; }
      if (job.kind !== "clear" && haveManifest) {
        history.reload(); history.waitForJob();
        try { Logic.parseState(history.text()); }
        catch (_) {
          corrupt = true; warning = "Clipboard history changed to invalid data. Back it up, then explicitly clear it to reset.";
          updateWatch(); done(); return;
        }
      }
      saved = false; history.setText(JSON.stringify({version: 1, items: value}) + "\n"); history.waitForJob();
      if (!saved) { fail("Could not save clipboard history."); done(); return; }
      secure(history.path, ok => {
        if (!ok) { fail("Cannot secure clipboard history."); done(); return; }
        haveManifest = true; items = value;
        collectImages(() => complete());
      });
    });
  }
  function collectImages(complete) {
    const paths = [];
    for (let i = 0; i < images.count; ++i) {
      const relative = "images/" + images.get(i, "fileName");
      if (Logic.managedImage(relative) && !items.some(item => item.file === relative)) paths.push(dir + "/" + relative);
    }
    if (!paths.length) { complete(); return; }
    command.run(["rm", "-f", "--"].concat(paths), () => complete());
  }
  function binary(args, complete) {
    binaryDone = complete; binaryPending = true; reader.command = args; reader.running = true; binaryTimeout.restart();
  }
  function binaryComplete(code) {
    if (!binaryPending) return;
    binaryPending = false; binaryTimeout.stop();
    const complete = binaryDone, data = bytes.data, text = bytes.text; binaryDone = null;
    Qt.callLater(() => complete(code, data, text));
  }
  Process {
    id: reader
    stdout: StdioCollector { id: bytes }
    stderr: StdioCollector {}
    onExited: (code, status) => root.binaryComplete(status === 0 ? code : 1)
    onRunningChanged: if (!running && root.binaryPending) Qt.callLater(() => { if (!reader.running && root.binaryPending) root.binaryComplete(127); })
  }
  Timer { id: binaryTimeout; interval: 5000; onTriggered: { reader.signal(9); } }
  function capture(job) {
    if (job.selection !== selection) { done(); return; }
    command.run(["wl-paste", "--list-types"], (code, output) => {
      const mime = code === 0 ? Logic.chooseMime(output) : "";
      if (!mime || !allowed(job.epoch) || job.selection !== selection) { done(); return; }
      binary(["wl-paste", "--no-newline", "--type", mime], (code, data, text) => {
        if (code !== 0 || !data.byteLength || !allowed(job.epoch) || job.selection !== selection) { done(); return; }
        const image = mime.startsWith("image/");
        if (image && data.byteLength > settings.value.maxImageBytes) { warning = "Clipboard image exceeds maxImageBytes."; done(); return; }
        // Hash and store exactly the bytes returned by wl-paste.
        const id = Logic.sha256(data);
        const item = {id: id, kind: image ? "image" : "text", mime: mime, time: Date.now()};
        if (image) { item.file = "images/" + id + "." + Logic.extension(mime); item.bytes = data.byteLength; }
        else item.text = text;
        Common.Privacy.check(ok => {
          if (!ok || !allowed(job.epoch) || job.selection !== selection) { done(); return; }
          if (image) {
            const path = dir + "/" + item.file;
            command.run(["realpath", "-m", "--", path], (code, output) => {
              if (code !== 0 || output.trim() !== path || !allowed(job.epoch)) { fail("Unsafe clipboard image path."); done(); return; }
              payload.path = path; saved = false; payload.setData(data); payload.waitForJob();
              if (!saved) { fail("Cannot store clipboard image."); done(); return; }
              secure(path, ok => {
                if (!ok) { fail("Cannot secure clipboard image."); done(); return; }
                safeImages = Object.assign({}, safeImages, {[item.file]: true});
                persist([item].concat(items.filter(old => old.id !== id)).slice(0, settings.value.historySize), job, done);
              });
            });
          } else persist([item].concat(items.filter(old => old.id !== id)).slice(0, settings.value.historySize), job, done);
        });
      });
    });
  }
  function copyItem(job) {
    error = "";
    const item = items.find(item => item.id === job.value);
    if (!item) { done(); return; }
    const path = item.kind === "image" ? dir + "/" + item.file : dir + "/.copy";
    if (item.kind === "image" && !Logic.managedImage(item.file)) { done(); return; }
    if (item.kind === "text") {
      payload.path = path; saved = false; payload.setText(item.text); payload.waitForJob();
      if (!saved) { copyError("Cannot prepare clipboard text."); done(); return; }
    }
    // Reject symlinks escaping storage, even for syntactically managed names.
    command.run(["realpath", "-e", "--", path], (code, output) => {
      if (code !== 0 || output.trim() !== path) { copyError("Clipboard payload is missing or unsafe."); done(); return; }
      secure(path, ok => {
        if (!ok) { copyError("Cannot secure clipboard payload."); done(); return; }
        Common.Privacy.check(ok => {
          if (!ok || !allowed(job.epoch)) { done(); return; }
          ownerUnit = "astral-clipboard-copy-" + Date.now() + "-" + Math.floor(Math.random() * 100000);
          command.run(["systemd-run", "--user", "--collect", "--quiet", "--unit=" + ownerUnit,
            "--property=Type=exec", "--property=UMask=0077", "--property=StandardInput=file:" + Logic.specifier(path),
            "--expand-environment=no", "--", "wl-copy", "--foreground", "--type", item.mime || "text/plain;charset=utf-8"], code => {
            if (code !== 0 || !allowed(job.epoch)) {
              Quickshell.execDetached(["systemctl", "--user", "stop", ownerUnit]);
              copyError("Could not start clipboard owner."); cleanupCopy(); return;
            }
            confirm(item, job, Date.now() + 3000);
          });
        });
      });
    });
  }
  function confirm(item, job, deadline) {
    if (!allowed(job.epoch)) { cleanupCopy(); return; }
    binary(["wl-paste", "--no-newline", "--type", item.mime || "text/plain;charset=utf-8"], (code, data) => {
      if (!allowed(job.epoch)) { cleanupCopy(); return; }
      if (code === 0 && Logic.sha256(data) === item.id) {
        Common.Privacy.check(ok => {
          if (ok && allowed(job.epoch)) copied();
          cleanupCopy();
        });
      } else if (Date.now() < deadline) { confirmRetry.callback = () => confirm(item, job, deadline); confirmRetry.restart(); }
      else { copyError("Clipboard ownership was not confirmed."); cleanupCopy(); }
    });
  }
  Timer { id: confirmRetry; property var callback: null; interval: 50; onTriggered: callback() }
  function cleanupCopy() { command.run(["rm", "-f", "--", dir + "/.copy"], () => done()); }
  function updateWatch() {
    const enabled = ready && !corrupt && Common.Privacy.ready && !Common.Privacy.blocked;
    if (enabled && !watcher.running && !watchProbe.running) {
      const token = epoch;
      // An empty selection may produce no initial callback. Only skip an initial
      // data notification when an existing selection was actually present.
      watchProbe.run(["wl-paste", "--list-types"], (code, output) => {
        if (!ready || corrupt || !allowed(token)) { Qt.callLater(updateWatch); return; }
        skipInitial = code === 0 && output.trim() !== "";
        watcher.running = true;
      });
    }
    if (!enabled) watcher.running = false;
  }
  Process {
    id: watcher
    // The child ignores selection stdin; stdout carries only state notifications.
    command: ["wl-paste", "--watch", "printenv", "CLIPBOARD_STATE"]
    stdout: SplitParser {
      onRead: state => {
        root.selection++;
        if (root.skipInitial) { root.skipInitial = false; return; }
        if (state === "data" && root.allowed(root.epoch)) root.enqueue("capture");
      }
    }
    stderr: StdioCollector {}
    onExited: retryWatch.restart()
  }
  Timer { id: retryWatch; interval: 3000; onTriggered: root.updateWatch() }
  Connections {
    target: Common.Privacy
    function onBlockedChanged() {
      if (Common.Privacy.blocked) {
        root.epoch++; root.selection++; root.queue = [];
        if (reader.running) reader.signal(9);
        if (root.ownerUnit) Quickshell.execDetached(["systemctl", "--user", "stop", root.ownerUnit]);
      }
      root.updateWatch();
    }
    function onReadyChanged() { root.updateWatch(); }
  }
  Connections { target: root.settings; function onValueChanged() { root.trim(); } }
  Component.onCompleted: storeLock.acquire()
}
