pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../settings" as Settings

Scope {
  id: root
  property var applications: Settings.SettingsData.value.applications
  readonly property string launchHelper: decodeURIComponent(Qt.resolvedUrl("../display/open-result.sh").toString().replace(/^file:\/\//, ""))
  property var entries: []
  property var popups: []
  property bool sessionBlocked: false
  onSessionBlockedChanged: if (sessionBlocked) for (const popup of popups.slice()) hide(popup.id)
  property bool dnd: false
  property int readers: 0
  property var focusedScreen: null
  property var surfaces: []
  readonly property int unread: entries.filter(entry => !entry.read).length
  onReadersChanged: if (readers > 0) markAllRead()
  onDndChanged: if (dnd) for (const popup of popups.slice()) hide(popup.id)

  NotificationServer {
    actionsSupported: true
    persistenceSupported: true
    keepOnReload: false
    onNotification: notification => {
      notification.tracked = true;
      const watcher = observer.createObject(root, {live: notification});
      watcher.ready = true;
      root.receive(notification);
    }
  }
  // Property changes, rather than notification(), report replacements in 0.3.2.
  Component {
    id: observer
    QtObject {
      id: watch
      required property var live
      property bool ready: false
      readonly property var snapshot: live ? [live.appName, live.appIcon, live.summary,
        live.body, live.urgency, live.expireTimeout, live.transient, live.resident,
        live.desktopEntry, Array.from(live.actions, action => [action.identifier, action.text]), live.hints] : []
      onSnapshotChanged: if (ready) Qt.callLater(refresh)
      function refresh(): void { if (live) root.receive(live); }
      property Connections connection: Connections {
        target: watch.live
        function onClosed() {
          const id = watch.live.id;
          watch.live = null;
          root.closed(id);
          watch.destroy();
        }
      }
    }
  }
  // Run the desktop opener asynchronously so portal/app startup cannot freeze QML.
  property var launchUrl: function(url, entryId, folder) {
    const request = fileLauncher.createObject(root, {url: url, entryId: entryId, folder: folder});
    request.running = true;
    return true;
  }
  Component {
    id: fileLauncher
    Process {
      id: launcher
      required property string url
      required property int entryId
      required property bool folder
      readonly property string path: decodeURIComponent(url.slice(7))
      command: ["bash", root.launchHelper, folder ? "folder" : /\.(mkv|mp4|webm|avi|mov|m4v|mpeg|mpg|ogv|ts)$/i.test(path) ? "video" : "file", path,
        JSON.stringify(root.applications.fileManager), JSON.stringify(root.applications.terminal), JSON.stringify(root.applications.videoPlayer)]
      stderr: StdioCollector { id: launchErrors }
      onExited: (code, status) => {
        root.finishLaunch(entryId, code === 0 && status === 0, launchErrors.text.trim());
        Qt.callLater(() => launcher.destroy());
      }
    }
  }
  function updateLaunch(id, changes): void {
    entries = entries.map(item => item.id === id ? Object.assign({}, item, changes) : item);
    popups = popups.map(item => item.id === id ? Object.assign({}, item,
      {entry: Object.assign({}, item.entry, changes), remaining: 8000}) : item);
  }
  function finishLaunch(id, accepted, message): void {
    updateLaunch(id, {launchState: accepted ? "idle" : "error",
      launchMessage: accepted ? "" : message || "Could not open this file. Check the default app and try again."});
  }
  function openFile(file, folder): void {
    let entry = entries.find(item => item.file === file);
    if (!entry) { localFile("Capture saved", file); entry = entries[0]; }
    invoke(entry.id, folder ? "folder" : "default");
  }
  property int nextLocalId: -1
  function localFile(summary, file): void {
    const entry = {id: nextLocalId--, app: "Screen & capture", icon: "", summary: summary,
      body: file, file: file, urgency: 1, time: new Date(), read: readers > 0,
      live: null, desktopEntry: "", actions: [{id: "default", text: "Open file"}, {id: "folder", text: "Open folder"}]};
    entries = [entry].concat(entries);
    while (entries.length > 100) remove(entries[entries.length - 1].id);
    if (!dnd && !sessionBlocked) {
      popups = popups.concat([{id: entry.id, entry: entry, screen: focusedScreen, remaining: 6000, paused: false}]);
      while (popups.length > 3) hide(popups[0].id);
    }
  }
  function receive(n): void {
    const entry = {id: n.id, app: n.appName || "Application", icon: n.appIcon,
      summary: n.summary, body: n.body, urgency: n.urgency,
      time: new Date(), read: readers > 0, live: n, desktopEntry: n.desktopEntry,
      actions: Array.from(n.actions, action => ({id: action.identifier, text: action.text}))};
    entries = entries.filter(item => item.id !== n.id);
    if (!n.transient) entries = [entry].concat(entries);
    while (entries.length > 100) remove(entries[entries.length - 1].id);
    popups = popups.filter(item => item.id !== n.id);
    if (!dnd && !sessionBlocked) {
      // expireTimeout is passed through in milliseconds in Quickshell 0.3.2.
      const remaining = n.urgency === NotificationUrgency.Critical || n.expireTimeout === 0
        ? -1 : n.expireTimeout < 0 ? 6000 : n.expireTimeout;
      popups = popups.concat([{id: n.id, entry: entry, screen: focusedScreen,
        remaining: remaining, paused: false}]);
      while (popups.length > 3) hide(popups[0].id);
    } else if (n.transient) {
      // Wait until Notify has registered the object before closing it.
      Qt.callLater(() => { if (n.tracked) n.expire(); });
    }
  }
  function closed(id): void {
    popups = popups.filter(item => item.id !== id);
    entries = entries.map(item => item.id === id
      ? Object.assign({}, item, {live: null, actions: []}) : item);
  }
  function markAllRead(): void {
    entries = entries.map(item => Object.assign({}, item, {read: true}));
    popups = popups.map(item => Object.assign({}, item,
      {entry: Object.assign({}, item.entry, {read: true})}));
  }
  function markRead(id): void {
    entries = entries.map(item => item.id === id ? Object.assign({}, item, {read: true}) : item);
    popups = popups.map(item => item.id === id ? Object.assign({}, item,
      {entry: Object.assign({}, item.entry, {read: true})}) : item);
  }
  function find(id) {
    return entries.find(item => item.id === id) || (popups.find(item => item.id === id) || {}).entry;
  }
  function hide(id): void {
    const popup = popups.find(item => item.id === id);
    popups = popups.filter(item => item.id !== id);
    if (popup && popup.entry.live && !entries.some(item => item.id === id)) popup.entry.live.expire();
  }
  function remove(id): void {
    const entry = find(id);
    entries = entries.filter(item => item.id !== id);
    popups = popups.filter(item => item.id !== id);
    if (entry && entry.live) entry.live.dismiss();
  }
  function clear(): void { for (const item of entries.slice()) remove(item.id); }
  function invoke(id, actionId): void {
    const entry = find(id);
    if (entry && entry.file) {
      if (!["default", "folder"].includes(actionId)) return;
      if (entry.launchState === "opening") return;
      markRead(id);
      hide(id);
      updateLaunch(id, {launchState: "opening", launchMessage: actionId === "folder" ? "Opening folder…" : "Opening file in your default app…"});
      const url = "file://" + (actionId === "folder" ? entry.file.slice(0, entry.file.lastIndexOf("/")) : entry.file).split("/").map(part => encodeURIComponent(part)).join("/");
      Qt.callLater(() => {
        if (root.launchUrl(url, id, actionId === "folder") === false) root.finishLaunch(id, false, "Could not send the open request.");
      });
      return;
    }
    if (!entry || !entry.live) return;
    markRead(id);
    const action = Array.from(entry.live.actions).find(item => item.identifier === actionId);
    if (action) { hide(id); action.invoke(); }
  }
  function canOpen(entry): bool {
    return entry.actions.some(action => action.id === "default")
      || !!(entry.desktopEntry && DesktopEntries.byId(entry.desktopEntry));
  }
  function open(id): void {
    const entry = find(id);
    if (!entry) return;
    if (entry.actions.some(action => action.id === "default")) invoke(id, "default");
    else {
      const app = entry.desktopEntry ? DesktopEntries.byId(entry.desktopEntry) : null;
      if (app) { markRead(id); hide(id); app.execute(); }
    }
  }
  function pause(id, value): void {
    const popup = popups.find(item => item.id === id);
    if (popup) popup.paused = value;
  }
  property double lastTick: Date.now()
  Timer {
    interval: 100; repeat: true; running: root.popups.length > 0
    onRunningChanged: root.lastTick = Date.now()
    onTriggered: {
      const now = Date.now();
      const elapsed = now - root.lastTick;
      root.lastTick = now;
      for (const popup of root.popups.slice()) {
        if (popup.paused || popup.entry.launchState === "opening" || popup.remaining < 0) continue;
        popup.remaining -= elapsed;
        if (popup.remaining <= 0) root.hide(popup.id);
      }
    }
  }
}
