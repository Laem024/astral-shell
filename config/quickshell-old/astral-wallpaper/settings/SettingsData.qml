pragma Singleton
import QtQuick
import Quickshell.Io
import "Settings.js" as Settings

QtObject {
  id: root
  property string error: ""
  readonly property url settingsPath: Qt.resolvedUrl("../settings.json")
  property FileView file: FileView {
    blockLoading: true
    path: root.settingsPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.load(text())
  }
  // Read synchronously so every consumer starts with complete values.
  property var value: root.loadInitial()

  function loadInitial() {
    try {
      return Settings.parse(file.text());
    } catch (e) {
      error = "Invalid settings: " + e.message;
      console.warn(error);
      return {};
    }
  }
  function load(text) {
    try {
      value = Settings.parse(text);
      error = "";
    } catch (e) {
      error = "Invalid settings: " + e.message;
      console.warn(error);
    }
  }
  // Persist a theme change so the wallpaper panel keeps it across restarts.
  // FileView writes atomically and reports the reloaded file through watchChanges.
  function setMode(mode) {
    if (!["light", "dark"].includes(mode) || !value || !value.mode || value.mode === mode) return false;
    const next = Object.assign({}, value, {mode: mode});
    value = next;
    file.setText(JSON.stringify(next, null, 2) + "\n");
    return true;
  }
}
