pragma Singleton
import QtQuick
import Quickshell

QtObject {
  function base(name, fallback) { const value = Quickshell.env(name) || ""; return value.startsWith("/") ? value : fallback; }
  readonly property string home: Quickshell.env("HOME")
  readonly property string runtime: base("XDG_RUNTIME_DIR", "") + "/astral-shell"
  readonly property string cache: base("XDG_CACHE_HOME", home + "/.cache") + "/astral-shell"
  readonly property string state: base("XDG_STATE_HOME", home + "/.local/state") + "/astral-shell"
  function localPath(url) { return decodeURIComponent(url.toString().replace(/^file:\/\//, "")); }
}
