import QtQuick
import "Logic.js" as Logic

Image {
  id: root
  required property var service
  property string path: ""
  property string thumbnail: ""
  property string requestedPath: ""
  property bool initialized: false
  property bool failed: false
  property int generation: 0
  property var lifetime: ({alive: true})
  Component.onDestruction: lifetime.alive = false
  readonly property bool video: Logic.kind(path) === "video"
  source: Logic.fileUrl(video ? thumbnail : path)
  asynchronous: true
  fillMode: Image.PreserveAspectCrop
  function refresh() {
    if (!initialized || !video || !path) return;
    requestedPath = path;
    const revision = ++generation, life = lifetime;
    service.thumbnails.request(path, result => {
      if (!life.alive) return;
      if (revision !== generation) return;
      thumbnail = result; failed = !result;
    });
  }
  onPathChanged: { generation++; thumbnail = ""; failed = false; refresh(); }
  Component.onCompleted: { initialized = true; refresh(); }
}
