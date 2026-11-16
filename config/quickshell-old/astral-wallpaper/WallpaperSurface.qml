pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// qmllint disable uncreatable-type
PanelWindow {
  id: root
  required property var modelData
  required property var service
  screen: modelData
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Background
  WlrLayershell.namespace: "astral-wallpaper"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  color: "#151918"
  property var currentMedia: null
  property var incoming: null
  property int stagedSerial: -1
  property int showingSerial: -1
  property string showingPath: ""
  property string registeredName: ""
  function stage() {
    const t = service.transaction;
    if (!t || !t.paths[modelData.name]) return;
    // Finish an earlier fade before staging another transaction.
    fade.stop(); cleanup();
    if (incoming) { incoming.destroy(); incoming = null; }
    stagedSerial = t.serial;
    if (showingPath === t.paths[modelData.name] && currentMedia) {
      Qt.callLater(() => service.prepared(modelData.name, t.serial)); return;
    }
    incoming = media.createObject(canvas, {path: t.paths[modelData.name], opacity: 0, requestSerial: t.serial});
  }
  function cleanup() {
    if (showingSerial < 0) return;
    if (currentMedia) currentMedia.destroy();
    currentMedia = incoming; incoming = null; showingSerial = -1;
  }
  Component.onCompleted: {
    registeredName = modelData.name;
    service.renderers[registeredName] = root;
    if (service.transaction) stage(); else Qt.callLater(service.restore);
  }
  Component.onDestruction: {
    if (service.renderers[registeredName] === root) delete service.renderers[registeredName];
  }
  Item {
    anchors.fill: parent; clip: true
    Item {
      id: canvas
      x: root.service.state.layout === "Span" ? root.service.geometry.x - root.modelData.x : 0
      y: root.service.state.layout === "Span" ? root.service.geometry.y - root.modelData.y : 0
      width: root.service.state.layout === "Span" ? root.service.geometry.width : root.width
      height: root.service.state.layout === "Span" ? root.service.geometry.height : root.height
    }
  }
  Component {
    id: media
    WallpaperMedia {
      id: playback
      property int requestSerial: -1
      anchors.fill: parent
      paused: root.service.blocked || playback !== root.currentMedia && root.showingSerial < 0
      onPrepared: {
        // Cached images/GIFs can become ready inside createObject(). Wait until
        // every surface has stored its incoming object before committing.
        const serial = playback.requestSerial;
        Qt.callLater(() => root.service.prepared(root.modelData.name, serial));
      }
      onFailed: detail => {
        const serial = playback.requestSerial;
        Qt.callLater(() => {
          if (root.service.transaction && root.service.transaction.serial === serial) root.service.failed(root.modelData.name, serial, detail);
          else root.service.error = detail;
        });
      }
    }
  }
  Connections {
    target: root.service
    function onTransactionChanged() { if (root.service.transaction && root.service.transaction.serial !== root.stagedSerial) root.stage(); }
    function onCommitted(id) {
      if (id !== root.stagedSerial || !root.incoming) return;
      root.showingSerial = id;
      root.showingPath = root.incoming.path;
      fade.target = root.incoming;
      fade.start();
    }
    function onCancelled(id) {
      if (id !== root.stagedSerial) return;
      if (root.incoming) root.incoming.destroy(); root.incoming = null;
    }
  }
  NumberAnimation {
    id: fade; property: "opacity"; from: 0; to: 1
    duration: root.service.fadeDuration
    onFinished: root.cleanup()
  }
}
