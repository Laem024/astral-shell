import QtQuick
import Quickshell
import "../../common" as Common

QtObject {
  id: root
  property var queue: []
  readonly property int maximumPending: 64
  property var requests: ({})
  property string directory: Common.Paths.cache + "/astral-wallpaper"
  property bool ready: false
  onReadyChanged: if (ready) pump()
  property var workers: [first, second]
  property ThumbnailWorker first: ThumbnailWorker { directory: root.directory; onFinished: (key, path) => root.complete(key, path) }
  property ThumbnailWorker second: ThumbnailWorker { directory: root.directory; onFinished: (key, path) => root.complete(key, path) }
  function request(path, done) {
    // A new stat is required even for paths absent from the current library.
    const key = path;
    if (requests[key]) { requests[key].push(done); return; }
    if (queue.length >= maximumPending) complete(queue.shift(), "");
    requests[key] = [done]; queue.push(key); pump();
  }
  function pump() {
    if (!ready) return;
    for (const worker of workers) if (!worker.busy && queue.length) worker.start(queue.shift());
  }
  function complete(key, path) {
    const callbacks = requests[key] || []; delete requests[key];
    for (const callback of callbacks) callback(path);
    Qt.callLater(pump);
  }
}
