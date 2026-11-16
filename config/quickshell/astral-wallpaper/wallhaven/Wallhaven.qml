import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common
import "WallhavenLogic.js" as Logic

Scope {
  id: root
  property string key: ""
  property bool running: false
  property string operation: ""
  property string url: ""
  property string work: ""
  property string destination: ""
  property string target: ""
  property string error: ""
  property string requestedPurity: "100"
  property string authenticatedUrl: ""
  signal finished(int code, var result, string error)
  Common.Command { id: command; timeout: 30000 }
  FileView { id: body; path: root.work ? root.work + "/body" : ""; blockLoading: true; printErrors: false }
  function complete(code, result, message) {
    command.run(["rm", "-rf", "--", work], () => { work = ""; running = false; finished(code, result, message); });
  }
  function start(kind, request) {
    if (running) return;
    operation = kind; running = true; error = "";
    if (kind === "search") {
      try { url = Logic.searchUrl(request, key); }
      catch (e) { running = false; finished(1, {}, e.message); return; }
      requestedPurity = (request.filters || {}).purity || "100";
    } else {
      if (!Logic.downloadUrl(request.url) || !["light", "dark", "shared"].includes(request.collection) || !request.folder.startsWith("/") || request.folder.includes("\0")) { running = false; finished(1, {}, "Invalid Wallhaven download URL or destination."); return; }
      url = request.url;
      destination = request.folder + (request.collection === "shared" ? "" : "/" + request.collection);
      target = destination + "/" + url.split("/").pop();
    }
    // Each request owns one private directory; download staging is on its target filesystem.
    const parent = kind === "search" ? Common.Paths.cache + "/astral-wallpaper" : destination;
    command.run(["mkdir", "-p", "--", parent], code => {
      if (code !== 0) { running = false; finished(1, {}, "Cannot create download directory."); return; }
      command.run(["mktemp", "-d", parent + "/.request-XXXXXXXX"], (code, output) => {
        if (code !== 0) { running = false; finished(1, {}, "Cannot prepare download."); return; }
        work = output.trim();
        authenticatedUrl = url + (kind === "search" && key ? "&apikey=" + key : "");
        transfer.stdinEnabled = true; transfer.running = true; deadline.restart();
      });
    });
  }
  Process {
    id: transfer
    // curl's user configuration is disabled. Secrets are supplied only on stdin.
    command: ["curl", "--disable", "--config", "-", "--silent", "--proto", "=https", "--connect-timeout", "15", "--max-time", "180", "--max-filesize", root.operation === "search" ? "2097152" : "104857600", "--output", root.work + "/body", "--write-out", "%{http_code}"]
    stdinEnabled: true
    stdout: StdioCollector { id: http }
    stderr: StdioCollector {}
    onStarted: { write('url = "' + root.authenticatedUrl + '"\n'); root.authenticatedUrl = ""; stdinEnabled = false; }
    onExited: (code, status) => {
      deadline.stop();
      if (code !== 0 || status !== 0) { root.complete(1, {}, "Network error. Check your connection and try again."); return; }
      if (http.text.trim() !== "200") { root.complete(1, {}, Logic.httpError(http.text.trim())); return; }
      if (root.operation === "search") {
        try { body.reload(); const result = Logic.parse(body.text(), root.requestedPurity); root.complete(0, result, ""); }
        catch (e) { root.complete(1, {}, "Invalid Wallhaven response."); }
      } else {
        command.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name", "-of", "default=noprint_wrappers=1:nokey=1", root.work + "/body"], (code, output) => {
          const expected = root.target.endsWith(".jpg") ? "mjpeg" : root.target.endsWith(".png") ? "png" : "webp";
          if (code !== 0 || output.trim() !== expected) { root.complete(1, {}, "The downloaded image is damaged or unsupported."); return; }
          command.run(["ffmpeg", "-v", "error", "-nostdin", "-i", root.work + "/body", "-frames:v", "1", "-f", "null", "-"], code => {
            if (code !== 0) { root.complete(1, {}, "The downloaded image is damaged."); return; }
            command.run(["mv", "-f", "--", root.work + "/body", root.target], code => root.complete(code, {path: root.target}, code ? "Could not publish the wallpaper." : ""));
          });
        });
      }
    }
    onRunningChanged: if (!running && root.running && root.work) Qt.callLater(() => {
      if (root.authenticatedUrl) { root.authenticatedUrl = ""; deadline.stop(); root.complete(1, {}, "Could not start curl."); }
    })
  }
  Timer { id: deadline; interval: 185000; onTriggered: if (transfer.running) transfer.signal(9) }
}
