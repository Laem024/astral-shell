import QtQuick
import Quickshell.Io
import "Validation.js" as Validation

QtObject {
  id: root
  required property string path
  required property string scope
  required property var defaults
  property var value: defaults
  property string error: ""
  function load(text): void {
    try { const next = Validation.parse(text, scope); value = scope === "common" ? Object.assign({}, defaults, next) : next; error = ""; }
    catch (e) { error = "Invalid settings: " + e.message; console.warn(path + ": " + error); }
  }
  property FileView file: FileView {
    path: root.path
    atomicWrites: true
    blockWrites: true
    blockLoading: true
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.load(text())
    onSaved: root.error = ""
    onSaveFailed: root.error = "Cannot save settings: " + root.path
    onLoadFailed: { root.error = "Cannot read settings: " + root.path; console.warn(root.error); }
  }
  function setMode(mode) {
    if (scope !== "common" || !["light", "dark"].includes(mode)) return false;
    try {
      file.reload();
      const next = Validation.parse(file.text(), scope);
      next.mode = mode;
      Validation.parse(JSON.stringify(next), scope);
      file.setText(JSON.stringify(next, null, 2) + "\n");
      file.waitForJob();
      if (error) return false;
      value = next;
      return true;
    } catch (e) { error = "Cannot update theme: " + e.message; return false; }
  }
  Component.onCompleted: load(file.text())
}
