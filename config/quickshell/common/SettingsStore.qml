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
  function previewPatch(baseline, changes) { return Validation.patch(Validation.parse(file.text(), scope), baseline, changes, scope); }
  function updateFields(baseline, changes) {
    try {
      error = "";
      file.reload();
      file.waitForJob();
      const next = Validation.patch(Validation.parse(file.text(), scope), baseline, changes, scope);
      const encoded = JSON.stringify(next, null, 2) + "\n";
      file.setText(encoded);
      file.waitForJob();
      if (error) return false;
      file.reload();
      file.waitForJob();
      if (file.text() !== encoded) throw new Error("Write verification failed");
      value = next;
      return true;
    } catch (e) { error = "Cannot update settings: " + e.message; return false; }
  }
  function setMode(mode) {
    if (scope !== "common" || !["light", "dark"].includes(mode)) return false;
    return updateFields(value, {mode: mode});
  }
  Component.onCompleted: load(file.text())
}
