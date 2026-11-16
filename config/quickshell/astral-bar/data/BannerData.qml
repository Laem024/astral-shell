pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common

Singleton {
  id: root
  readonly property string directory: Common.Paths.state + "/profile"
  property string file: ""
  property real zoom: 1
  property real focusX: 0.5
  property real focusY: 0.5
  readonly property url source: file ? fileUrl(directory + "/" + file) : ""
  property bool busy: false
  property string error: ""
  property string previous: ""
  property var pendingCrop: null
  property string pendingFile: ""
  signal saved()
  function fileUrl(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/"); }
  function managed(name) { return /^banner-[A-Za-z0-9-]+$/.test(name); }
  function validCrop(crop) {
    return crop && Number.isFinite(crop.zoom) && crop.zoom >= 1 && crop.zoom <= 4
      && Number.isFinite(crop.focusX) && crop.focusX >= 0 && crop.focusX <= 1
      && Number.isFinite(crop.focusY) && crop.focusY >= 0 && crop.focusY <= 1;
  }
  function load() {
    if (busy) return;
    try {
      const data = JSON.parse(manifest.text());
      if (data.file && !managed(data.file) || !validCrop(data.crop)) throw new Error("format");
      file = data.file; zoom = data.crop.zoom; focusX = data.crop.focusX; focusY = data.crop.focusY;
    } catch (_) { if (manifest.text().trim()) error = "Unable to read saved banner."; }
  }
  function save(source, crop) {
    if (busy || !validCrop(crop)) return;
    const url = source.toString();
    if (!url.startsWith("file:///")) { error = "Choose a local PNG or JPEG."; return; }
    let path;
    try { path = decodeURIComponent(url.slice(7)); } catch (_) { error = "Invalid image path."; return; }
    if (/[\u0000\r\n]/.test(path)) return;
    busy = true; error = "";
    pendingCrop = crop; pendingFile = "banner-" + Date.now() + "-" + Math.random().toString(36).slice(2);
    worker.run(["mkdir", "-p", "-m", "700", "--", Common.Paths.state, directory], code => {
      if (code !== 0) { busy = false; error = "Cannot create banner directory."; return; }
      worker.run(["cp", "--", path, directory + "/" + pendingFile], code => {
        if (code !== 0) { busy = false; error = "Cannot copy banner."; return; }
        manifest.setText(JSON.stringify({file: pendingFile, crop: pendingCrop}));
      });
    });
  }
  function remove() {
    if (busy || !file) return;
    busy = true; pendingFile = ""; pendingCrop = {zoom: 1, focusX: 0.5, focusY: 0.5};
    manifest.setText(JSON.stringify({file: "", crop: pendingCrop}));
  }
  Common.Command { id: worker }
  FileView {
    id: manifest
    path: root.directory + "/banner.json"
    blockLoading: true
    printErrors: false
    atomicWrites: true
    onSaved: {
      const previous = root.file;
      root.file = root.pendingFile; root.zoom = root.pendingCrop.zoom;
      root.focusX = root.pendingCrop.focusX; root.focusY = root.pendingCrop.focusY;
      if (root.managed(previous)) worker.run(["rm", "-f", "--", root.directory + "/" + previous], code => {
        root.busy = false; if (code !== 0) root.error = "Could not remove previous banner."; root.saved();
      });
      else { root.busy = false; root.saved(); }
    }
    onSaveFailed: {
      root.error = "Cannot save banner manifest."; root.busy = false;
      if (root.managed(root.pendingFile)) worker.run(["rm", "-f", "--", root.directory + "/" + root.pendingFile], null);
    }
  }
  Component.onCompleted: load()
}
