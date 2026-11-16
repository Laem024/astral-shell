import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

Scope {
  id: root
  required property var settings
  property bool blocked: true
  property var screens: Quickshell.screens
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("backend.sh").toString().replace(/^file:\/\//, ""))
  property var state: Logic.defaults(Quickshell.env("HOME") + "/Pictures/Wallpapers")
  property var entries: []
  readonly property string collection: Logic.theme(settings.value.mode)
  readonly property var available: Logic.collection(entries, collection, "")
  property var activePaths: ({})
  property string activeCollection: ""
  property string activeLayout: ""
  property var renderers: ({})
  property var transaction: null
  property int serial: 0
  property bool ready: false
  property bool dirty: false
  property bool scanning: false
  property bool rescan: false
  property string error: ""
  property string warning: ""
  property string notice: ""
  property bool restorePending: true
  property bool suppressRestore: false
  property int contextRevision: 0
  property string query: ""
  property var remoteEntries: []
  property int page: 1
  property int lastPage: 1
  property bool remoteBusy: false
  property string remoteOperation: ""
  property var remoteRequest: ({})
  property var pendingDownloadApply: null
  property string downloadCollection: "shared"
  property bool keySaved: false
  property string keyInput: ""
  readonly property bool keyBusy: keyWriter.running
  readonly property var geometry: Logic.bounds(screens)
  readonly property int fadeDuration: settings.value.animations ? state.fade : 0
  signal committed(int serial)
  signal cancelled(int serial)
  signal applied()
  signal downloaded(string source, string path)
  onCollectionChanged: if (ready && !suppressRestore) { contextRevision++; cancelLoad(); restorePending = true; restore(); }
  onScreensChanged: if (ready) { contextRevision++; cancelLoad(); restorePending = true; Qt.callLater(restore); }
  onBlockedChanged: {
    contextRevision++;
    if (blocked && transaction && transaction.intent === "rotation") cancelLoad();
    restartRotation();
  }
  function cancelLoad() {
    if (transaction) { cancelled(transaction.serial); transaction = null; loadTimeout.stop(); }
  }
  function update(key, value) {
    if (!ready || (transaction && key !== "rotation")) return;
    if (["folder", "layout"].includes(key)) contextRevision++;
    const next = JSON.parse(JSON.stringify(state)); next[key] = value;
    state = next; save();
    if (key === "rotation" && !value && transaction && transaction.intent === "rotation") cancelLoad();
    if (key === "folder") { entries = []; refresh(); }
    else if (key === "layout") restore();
    restartRotation();
  }
  function restartRotation() {
    rotation.stop();
    rotation.running = Qt.binding(() => root.ready && root.state.rotation && !root.blocked);
  }
  function save() {
    dirty = true;
    if (ready && !writer.running) { dirty = false; writer.running = true; }
  }
  function refresh() {
    if (!ready) return;
    if (scanner.running) { rescan = true; return; }
    scanning = true;
    scanner.running = true;
  }
  function restore() {
    if (scanning || !ready) return;
    restorePending = false;
    const paths = Logic.assignments(state, collection, available.concat(entries.filter(e => !available.some(a => a.path === e.path))), screens.map(s => s.name));
    if (activeCollection === collection && activeLayout === state.layout) {
      for (const screen of screens) {
        const previous = activePaths[screen.name];
        if (previous && !entries.some(e => e.path === previous)) {
          paths[screen.name] = previous;
          warning = "The active wallpaper file is missing. This session keeps the current wallpaper.";
        }
      }
    }
    prepare(paths, "restore");
  }
  function assign(path, theme, monitor, layout) {
    if (!ready || scanning || transaction || blocked || !["light", "dark"].includes(theme) || !entries.some(e => e.path === path)) return;
    const next = JSON.parse(JSON.stringify(state));
    const selected = next.selections[theme];
    layout = layout || state.layout;
    Logic.ensureLayouts(selected);
    if (layout === "Per monitor") { selected.layouts[layout].monitors[monitor] = path; selected.monitors[monitor] = path; }
    else { selected.layouts[layout].common = path; selected.common = path; }
    next.layout = layout;
    // Assigning switches the module theme so the target collection is visible at once.
    suppressRestore = true;
    state = next;
    if (settings && typeof settings.setMode === "function") settings.setMode(theme);
    suppressRestore = false;
    save();
    const paths = {};
    for (const screen of screens) {
      const saved = layout === "Per monitor" ? selected.layouts[layout].monitors[screen.name] : "";
      paths[screen.name] = saved || path;
    }
    if (layout === "Per monitor" && screens.some(s => s.name === monitor)) paths[monitor] = path;
    error = "";
    notice = "Assigned and applied to " + (theme === "light" ? "Light" : "Dark") + " on " + (layout === "Per monitor" ? monitor : "all screens") + ".";
    prepare(paths, "assign", layout);
  }
  function apply(path, monitor, layout) {
    if (blocked || !ready || scanning || transaction || !screens.some(s => s.name === monitor) || !entries.some(e => e.path === path)) return;
    layout = layout || state.layout;
    const paths = {};
    for (const screen of screens) paths[screen.name] = activePaths[screen.name] || path;
    if (layout === "Per monitor") paths[monitor] = path;
    else for (const screen of screens) paths[screen.name] = path;
    error = ""; notice = "";
    prepare(paths, "manual", layout);
  }
  function prepare(paths, intent, layout) {
    cancelLoad();
    const names = Object.keys(paths).filter(n => paths[n]);
    if (!names.length) return;
    transaction = {serial: ++serial, paths: paths, waiting: names, theme: collection, layout: layout || state.layout, intent: intent};
    loadTimeout.restart();
  }
  function prepared(name, id) {
    if (!transaction || transaction.serial !== id) return;
    if (transaction.intent === "rotation" && (!state.rotation || blocked)) { cancelled(id); transaction = null; loadTimeout.stop(); return; }
    const t = Object.assign({}, transaction);
    t.waiting = t.waiting.filter(n => n !== name); transaction = t;
    if (t.waiting.length) return;
    loadTimeout.stop();
    const next = JSON.parse(JSON.stringify(state));
    const selected = next.selections[t.theme];
    Logic.ensureLayouts(selected);
    const previous = selected.layouts[t.layout] || selected;
    selected.monitors = Object.assign({}, previous.monitors);
    selected.common = previous.common;
    if (t.layout === "Per monitor") Object.assign(selected.monitors, t.paths);
    else selected.common = t.paths[Object.keys(t.paths)[0]];
    selected.layouts[t.layout] = {common: selected.common, monitors: Object.assign({}, selected.monitors)};
    next.layout = t.layout;
    activeCollection = t.theme; activeLayout = t.layout;
    activePaths = t.paths;
    state = next;
    transaction = null;
    committed(id); save(); restartRotation();
    if (t.intent === "manual" || t.intent === "assign") applied();
  }
  function failed(name, id, detail) {
    if (!transaction || transaction.serial !== id) return;
    cancelled(id); transaction = null; loadTimeout.stop();
    error = "Could not load the wallpaper on " + name + ". " + detail;
  }
  // The module theme selects the wallpaper collection, so changing it is enough.
  function setTheme(choice) {
    if (!ready || transaction || !["Light", "Dark"].includes(choice)) return;
    if (settings && typeof settings.setMode === "function") settings.setMode(choice.toLowerCase());
  }
  function rotate() {
    if (!state.rotation || blocked || transaction || scanning || available.length < 2) return;
    const paths = {};
    let common = "";
    for (const screen of screens) {
      if (state.layout !== "Per monitor" && common) paths[screen.name] = common;
      else {
        paths[screen.name] = Logic.choose(available, activePaths[screen.name], state.random);
        common = paths[screen.name];
      }
    }
    prepare(paths, "rotation");
  }
  function search(text, requestedPage) {
    if (remoteBusy) return;
    query = text;
    remoteOperation = "search";
    remoteRequest = {query: text, page: requestedPage};
    remoteBusy = true; error = ""; remote.running = true;
  }
  function invalidateDownloadTarget() {
    if (pendingDownloadApply && pendingDownloadApply.intent !== "download") contextRevision++;
  }
  function download(entry, target, monitor, intent, theme, layout) {
    if (remoteBusy || transaction || scanning || blocked || !ready) return;
    intent = intent || (monitor ? "manual" : "download");
    pendingDownloadApply = {revision: contextRevision, path: "", monitor: monitor || "", folder: state.folder, theme: collection, layout: state.layout,
      intent: intent, targetTheme: theme || collection, targetLayout: layout || state.layout};
    remoteOperation = "download";
    remoteRequest = {url: entry.path, folder: state.folder, collection: target, intent: intent};
    remoteBusy = true; error = ""; notice = ""; remote.running = true;
  }
  function setKey(text) {
    if (keyWriter.running) return;
    keyInput = text; keyWriter.running = true;
  }
  Process {
    id: reader
    command: ["bash", root.helper, "read"]
    running: true
    stdout: StdioCollector { id: contents }
    onExited: (code, status) => {
      try {
        if (code !== 0 || status !== 0) throw new Error("Could not read the wallpaper state.");
        if (contents.text.trim() !== "{}") root.state = Logic.parse(contents.text, root.state.folder);
      } catch (e) { root.warning = "The saved wallpaper state is invalid. Defaults will be used."; }
      root.ready = true; root.refresh();
    }
  }
  Process {
    id: writer
    command: ["bash", root.helper, "write"]
    stdinEnabled: true
    onStarted: { write(JSON.stringify(root.state) + "\n"); stdinEnabled = false; }
    onExited: (code, status) => {
      stdinEnabled = true;
      if (code !== 0 || status !== 0) root.warning = "Could not save the wallpaper preferences. Changes are kept for this session.";
      if (root.dirty) Qt.callLater(root.save);
    }
  }
  Process {
    id: scanner
    command: ["bash", root.helper, "scan"]
    stdinEnabled: true
    onStarted: { write(JSON.stringify({folder: root.state.folder}) + "\n"); stdinEnabled = false; }
    stdout: StdioCollector { id: catalog }
    stderr: StdioCollector { id: scanError }
    onExited: (code, status) => {
      stdinEnabled = true; root.scanning = false;
      if (code !== 0 || status !== 0) root.error = scanError.text.trim() || "Could not read the wallpaper library.";
      else {
        try { root.entries = JSON.parse(catalog.text).map(e => Object.assign(e, {theme: Logic.classify(e.relative), kind: Logic.kind(e.path)})); root.error = ""; }
        catch (e) { root.error = "Invalid wallpaper library response."; }
      }
      if (root.rescan) { root.rescan = false; root.refresh(); }
      else if (root.pendingDownloadApply && root.pendingDownloadApply.path) {
        const pending = root.pendingDownloadApply;
        root.pendingDownloadApply = null;
        if (pending.intent === "download") root.notice = "Saved to " + pending.path;
        else if (code === 0 && status === 0 && !root.error && !root.blocked && root.contextRevision === pending.revision && root.state.folder === pending.folder && root.collection === pending.theme && root.state.layout === pending.layout && root.screens.some(s => s.name === pending.monitor) && root.entries.some(e => e.path === pending.path)) {
          if (pending.intent === "assign") root.assign(pending.path, pending.targetTheme, pending.monitor, pending.targetLayout);
          else root.apply(pending.path, pending.monitor, pending.targetLayout);
        } else root.notice = "The wallpaper was downloaded, but the destination changed. You can choose it from Library.";
      } else if (root.restorePending) root.restore();
      else if (Object.values(root.activePaths).some(p => !root.entries.some(e => e.path === p))) root.warning = "The active wallpaper file is missing. This session keeps the current wallpaper.";
    }
  }
  Process {
    id: keyProbe
    command: ["bash", root.helper, "key-status"]; running: true
    stdout: StdioCollector { id: keyStatus }
    onExited: root.keySaved = keyStatus.text.trim() === "saved"
  }
  Process {
    id: keyWriter
    command: ["bash", root.helper, "key"]
    stdinEnabled: true
    onStarted: { write(JSON.stringify({key: root.keyInput}) + "\n"); root.keyInput = ""; stdinEnabled = false; }
    stderr: StdioCollector { id: keyError }
    onExited: (code, status) => {
      stdinEnabled = true;
      if (code !== 0 || status !== 0) root.error = keyError.text.trim() || "Could not save the API key.";
      keyProbe.running = true;
    }
  }
  Process {
    id: remote
    command: ["bash", root.helper, root.remoteOperation]
    stdinEnabled: true
    onStarted: { write(JSON.stringify(root.remoteRequest) + "\n"); stdinEnabled = false; }
    stdout: StdioCollector { id: remoteOutput }
    stderr: StdioCollector { id: remoteError }
    onExited: (code, status) => {
      stdinEnabled = true; root.remoteBusy = false;
      if (code !== 0 || status !== 0) { root.pendingDownloadApply = null; root.error = remoteError.text.trim() || "The Wallhaven request failed."; return; }
      try {
        const result = JSON.parse(remoteOutput.text);
        if (root.remoteOperation === "search") {
          root.remoteEntries = result.data; root.page = result.meta.current_page; root.lastPage = result.meta.last_page;
        } else {
          if (root.pendingDownloadApply) root.pendingDownloadApply = Object.assign({}, root.pendingDownloadApply, {path: result.path});
          root.downloaded(root.remoteRequest.url, result.path);
          root.refresh();
        }
      } catch (e) { root.pendingDownloadApply = null; root.error = "Invalid Wallhaven response."; }
    }
  }
  Timer { id: loadTimeout; interval: 30000; onTriggered: if (root.transaction) root.failed("screen", root.transaction.serial, "Loading timed out; the previous wallpaper is kept.") }
  Timer {
    id: rotation
    interval: Math.min(2147483647, root.state.minutes * 60000)
    repeat: true; running: root.ready && root.state.rotation && !root.blocked
    onTriggered: root.rotate()
  }
  // Logical screen coordinates already account for output scale and transform.
  // Periodic correction bounds ordinary drift; decoders are not frame locked.
  Timer {
    interval: 2000; repeat: true; running: !root.blocked && root.state.layout === "Span"
    onTriggered: {
      const players = root.screens.map(s => root.renderers[s.name]).filter(p => p && p.currentMedia);
      if (players.length < 2) return;
      const leader = players[0].currentMedia;
      for (let i = 1; i < players.length; i++) players[i].currentMedia.synchronize(leader);
    }
  }
}
