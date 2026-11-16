import QtQuick
import Quickshell.Io
import "Logic.js" as Logic

Image {
  id: root
  required property var service
  property string path: ""
  property string thumbnail: ""
  property string requestedPath: ""
  property bool initialized: false
  property bool failed: false
  readonly property bool video: Logic.kind(path) === "video"
  source: Logic.fileUrl(video ? thumbnail : path)
  asynchronous: true
  fillMode: Image.PreserveAspectCrop
  function refresh() {
    if (!initialized || !video || !path || request.running) return;
    requestedPath = path;
    request.running = true;
  }
  onPathChanged: { thumbnail = ""; failed = false; refresh(); }
  Component.onCompleted: { initialized = true; refresh(); }
  Process {
    id: request
    command: ["bash", root.service.helper, "thumbnail"]
    stdinEnabled: true
    onStarted: { write(JSON.stringify({path: root.requestedPath}) + "\n"); stdinEnabled = false; }
    stdout: StdioCollector { id: result }
    stderr: StdioCollector {}
    onExited: (code, status) => {
      stdinEnabled = true;
      if (root.path !== root.requestedPath) { Qt.callLater(root.refresh); return; }
      if (code === 0 && status === 0) {
        try { root.thumbnail = JSON.parse(result.text).path; }
        catch (e) { root.failed = true; }
      } else root.failed = true;
    }
  }
}
