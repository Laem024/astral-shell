import QtQuick
import Quickshell
import Quickshell.Io

// Unknown preferences, inhibitors or media state block automatic power actions.
Scope {
  id: root
  property var completion: null
  property var names: []
  property int index: 0
  readonly property bool running: completion !== null
  Command { id: request; timeout: 3000 }
  FileView { id: preference; path: Paths.state + "/caffeine"; printErrors: false; blockLoading: true }
  function check(includeMedia, done) {
    if (running) { done(false); return; }
    completion = done;
    preference.reload();
    // A missing preference is the default off state; other read failures block.
    request.run(["test", "-e", preference.path], code => {
      if (code !== 0 && code !== 1) { finish(false); return; }
      if (code === 0 && preference.text().trim() !== "off") { finish(false); return; }
      request.run(["busctl", "--system", "--json=short", "call", "org.freedesktop.login1",
        "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "ListInhibitors"], (code, output) => {
        try {
          const rows = JSON.parse(output).data[0];
          if (code !== 0 || !Array.isArray(rows) || rows.some(row => row[3] === "block" && row[0].split(":").includes("idle"))) { finish(false); return; }
        } catch (_) { finish(false); return; }
        if (includeMedia) listPlayers(); else finish(true);
      });
    });
  }
  function listPlayers() {
    request.run(["busctl", "--user", "--timeout=2", "--no-pager", "--no-legend", "list"], (code, output) => {
      if (code !== 0) { finish(false); return; }
      names = output.trim().split("\n").map(line => line.trim().split(/\s+/)[0]).filter(name => name.startsWith("org.mpris.MediaPlayer2."));
      index = 0; nextPlayer();
    });
  }
  function nextPlayer() {
    if (index >= names.length) { finish(true); return; }
    request.run(["busctl", "--user", "--timeout=2", "get-property", names[index++],
      "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "PlaybackStatus"], (code, output) => {
      if (code !== 0 || !['s "Paused"', 's "Stopped"'].includes(output.trim())) finish(false);
      else nextPlayer();
    });
  }
  function finish(allowed) { const done = completion; completion = null; if (done) done(allowed); }
}
