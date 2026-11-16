pragma Singleton
import QtQuick
import QtCore
import Quickshell

Singleton {
  id: root
  readonly property string task: ["shot", "record"].includes(saved.task) ? saved.task : "shot"
  readonly property string source: sources.includes(saved.source) ? saved.source : "monitor"
  readonly property var sources: task === "shot" ? ["monitor", "region", "window"] : ["monitor", "region"]
  readonly property string audio: ["none", "system", "microphone", "both"].includes(saved.audio) ? saved.audio : "none"
  readonly property string monitor: saved.monitor
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
  readonly property string file: (stateHome.startsWith("/") ? stateHome : Quickshell.env("HOME") + "/.local/state") + "/astral-shell/capture.ini"
  function selectTask(value): void { if (["shot", "record"].includes(value)) { saved.task = value; saved.sync(); } }
  function selectSource(value): void { if (sources.includes(value)) { saved.source = value; saved.sync(); } }
  function selectAudio(value): void { if (["none", "system", "microphone", "both"].includes(value)) { saved.audio = value; saved.sync(); } }
  function selectMonitor(value): void { if (typeof value === "string") { saved.monitor = value; saved.sync(); } }
  Settings {
    id: saved
    location: "file://" + root.file.split("/").map(part => encodeURIComponent(part)).join("/")
    category: "Capture"
    property string task: "shot"
    property string source: "monitor"
    property string audio: "none"
    property string monitor: ""
  }
}
