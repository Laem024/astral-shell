import QtQuick
import Quickshell
import Quickshell.Io
import "." as Common

Scope {
  id: root
  property string username: Quickshell.env("USER") || "user"
  property string fullName: ""
  property string home: Quickshell.env("HOME")
  property string iconFile: ""
  property int revision: 0
  readonly property string displayName: fullName.trim() || username
  readonly property url avatar: iconFile ? "file://" + encodeURI(iconFile).replace(/#/g, "%23").replace(/\?/g, "%3F") + "?v=" + revision : ""
  property bool busy: false
  property string error: ""
  property string accountPath: ""
  property var completion: null
  property bool capturing: false
  property var capture: null
  property string temporaryFile: ""
  signal saved()

  function run(args, callback) {
    completion = callback;
    worker.command = args;
    worker.running = true;
    watchdog.restart();
  }
  function call(args, callback) {
    run(["busctl", "--system", "--json=short", "call", "org.freedesktop.Accounts"].concat(args), callback);
  }
  function refresh() {
    if (busy) return;
    busy = true;
    error = "";
    run(["id", "-un"], (code, output) => {
      if (code === 0 && output.trim()) username = output.trim();
      run(["getent", "passwd", username], (status, entry) => {
        if (status === 0) {
          const fields = entry.trim().split(":");
          fullName = (fields[4] || "").split(",")[0];
          home = fields[5] || home;
        }
        call(["/org/freedesktop/Accounts", "org.freedesktop.Accounts", "FindUserByName", "s", username], (status, output) => {
          accountPath = "";
          if (status === 0) {
            try { accountPath = JSON.parse(output).data[0]; } catch (_) {}
          }
          if (!accountPath) {
            error = "Account service unavailable. Photo changes are disabled.";
            busy = false;
            return;
          }
          loadAccount();
        });
      });
    });
  }
  function loadAccount(notify = false) {
    call([accountPath, "org.freedesktop.DBus.Properties", "GetAll", "s", "org.freedesktop.Accounts.User"], (code, output) => {
      let loaded = false;
      try {
        if (code !== 0) throw new Error("read failed");
        const data = JSON.parse(output).data[0];
        if (typeof data.RealName.data !== "string" || typeof data.UserName.data !== "string" || typeof data.IconFile.data !== "string")
          throw new Error("invalid account details");
        fullName = data.RealName.data;
        username = data.UserName.data;
        iconFile = data.IconFile.data;
        revision++;
        error = "";
        loaded = true;
      } catch (_) { error = "Unable to read account details."; }
      busy = false;
      if (notify && loaded) saved();
    });
  }
  function saveAvatar(image) {
    if (busy || !accountPath || image.status !== Image.Ready || image.width <= 0 || image.width !== image.height) return;
    busy = true;
    error = "";
    capturing = true;
    captureDeadline.restart();
    if (!image.grabToImage(result => {
      if (!capturing) return;
      capturing = false;
      captureDeadline.stop();
      capture = result;
      run(["mkdir", "-p", "-m", "700", "--", Common.Paths.runtime], code => {
        if (code !== 0) { fail("Cannot create avatar runtime directory."); return; }
        run(["mktemp", "--suffix=.png", Common.Paths.runtime + "/avatar-XXXXXXXX"], (code, output) => {
        temporaryFile = code === 0 ? output.trim() : "";
        if (!temporaryFile) { fail("Unable to create temporary image."); return; }
        if (!capture.saveToFile(temporaryFile)) { cleanup("Unable to prepare image."); return; }
        capture = null;
        call([accountPath, "org.freedesktop.Accounts.User", "SetIconFile", "s", temporaryFile], (status) => {
          cleanup(status === 0 ? "" : "Unable to save photo. Check account service permissions.");
        });
      });
      });
    }, Qt.size(512, 512))) fail("Unable to prepare image.");
  }
  function fail(message) { capturing = false; captureDeadline.stop(); capture = null; error = message; busy = false; }
  function cleanup(message) {
    run(["rm", "-f", "--", temporaryFile], (code) => {
      temporaryFile = "";
      capture = null;
      if (message || code !== 0) { fail(message || "Unable to remove temporary image."); return; }
      loadAccount(true);
    });
  }
  Timer {
    id: captureDeadline
    interval: 5000
    onTriggered: root.fail("Image capture interrupted. Reopen the picker and try again.")
  }
  Timer {
    id: watchdog
    interval: 20000
    onTriggered: {
      if (worker.running) worker.signal(9);
      else {
        const callback = root.completion;
        root.completion = null;
        if (callback) callback(1, "");
      }
    }
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
