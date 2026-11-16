pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
  readonly property string directory: (stateHome.startsWith("/") ? stateHome : Quickshell.env("HOME") + "/.local/state") + "/astral-shell/profile"
  property string file: ""
  property real zoom: 1
  property real focusX: 0.5
  property real focusY: 0.5
  readonly property url source: file ? fileUrl(directory + "/" + file) : ""
  property bool busy: false
  property string error: ""
  property var completion: null
  signal saved()

  function fileUrl(path: string): string {
    return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
  }
  function managed(name: string): bool { return /^banner-[A-Za-z0-9]+$/.test(name); }
  function validCrop(crop): bool {
    return crop && typeof crop.zoom === "number" && Number.isFinite(crop.zoom) && crop.zoom >= 1 && crop.zoom <= 4
      && typeof crop.focusX === "number" && Number.isFinite(crop.focusX) && crop.focusX >= 0 && crop.focusX <= 1
      && typeof crop.focusY === "number" && Number.isFinite(crop.focusY) && crop.focusY >= 0 && crop.focusY <= 1;
  }
  function run(args, callback) {
    completion = callback;
    worker.command = args;
    worker.running = true;
    watchdog.restart();
  }
  function load(): void {
    if (busy) return;
    busy = true; error = "";
    run(["sh", "-c", 'if [ -e "$1/banner.json" ]; then cat -- "$1/banner.json"; fi', "banner-load", directory], (code, output) => {
      try {
        if (code !== 0) throw new Error("read");
        if (output.trim()) {
          const data = JSON.parse(output);
          if (!managed(data.file) || !validCrop(data.crop)) throw new Error("format");
          file = data.file;
          zoom = data.crop.zoom; focusX = data.crop.focusX; focusY = data.crop.focusY;
        } else { file = ""; zoom = 1; focusX = 0.5; focusY = 0.5; }
      } catch (_) { error = "Unable to read saved banner."; }
      busy = false;
    });
  }
  function save(source: url, crop): void {
    if (busy || !validCrop(crop)) return;
    const url = source.toString();
    if (!url.startsWith("file:///")) { error = "Choose a local PNG or JPEG."; return; }
    let path;
    try { path = decodeURIComponent(url.substring(7)); }
    catch (_) { error = "Invalid image path."; return; }
    busy = true; error = "";
    // Arguments carry user paths and JSON; shell text is constant. Publish the
    // manifest last, so failed writes cannot replace the current selection.
    const script = [
      'set -eu',
      'umask 077',
      'mkdir -p -- "$1"',
      'image=$(mktemp "$1/banner-XXXXXXXX")',
      'manifest=""',
      'trap \'rm -f -- "$image"; if [ -n "$manifest" ]; then rm -f -- "$manifest"; fi\' EXIT',
      'cp -- "$2" "$image"',
      'manifest=$(mktemp "$1/.banner-XXXXXXXX")',
      'name=${image##*/}',
      'printf \'{"file":"%s","crop":%s}\\n\' "$name" "$3" > "$manifest"',
      'mv -f -- "$manifest" "$1/banner.json"',
      'trap - EXIT',
      'printf \'%s\' "$name"'
    ].join("\n");
    run(["sh", "-c", script, "banner-save", directory, path, JSON.stringify(crop)], (code, output) => {
      if (code !== 0 || !managed(output)) { error = "Unable to save banner. Check available space and profile directory permissions."; busy = false; return; }
      const previous = file;
      file = output; zoom = crop.zoom; focusX = crop.focusX; focusY = crop.focusY;
      finish(previous);
    });
  }
  function remove(): void {
    if (busy || !file) return;
    busy = true; error = "";
    run(["rm", "-f", "--", directory + "/banner.json"], code => {
      if (code !== 0) { error = "Unable to remove banner."; busy = false; return; }
      const previous = file;
      file = ""; zoom = 1; focusX = 0.5; focusY = 0.5;
      finish(previous);
    });
  }
  function finish(previous: string): void {
    if (!managed(previous)) { busy = false; saved(); return; }
    run(["rm", "-f", "--", directory + "/" + previous], code => {
      if (code !== 0) error = "Banner saved, but the previous managed copy could not be removed.";
      busy = false;
      saved();
    });
  }
  Component.onCompleted: load()
  Timer {
    id: watchdog
    interval: 20000
    onTriggered: if (worker.running) worker.signal(15)
  }
  Process {
    id: worker
    stdout: StdioCollector { id: output }
    stderr: StdioCollector {}
    onExited: (code, status) => {
      watchdog.stop();
      const callback = root.completion;
      const result = output.text;
      root.completion = null;
      Qt.callLater(() => { if (callback) callback(code === 0 && status === 0 ? 0 : 1, result); });
    }
  }
}
