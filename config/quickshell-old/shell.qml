import QtQuick
import Quickshell
import Quickshell.Io

// Entrypoint for the Astral environment. Modules remain separate processes.
ShellRoot {
  id: root

  // Use paths relative to this file, or absolute paths for personal modules.
  // Lock remains on demand through astral-lock and is never started here.
  readonly property var modules: ({
    bar: { path: "astral-bar", autostart: true },
    launcher: { path: "astral-launcher", autostart: false },
    wallpaper: { path: "astral-wallpaper", autostart: true },
    clipboard: { path: "astral-clipboard", autostart: true },
    session: { path: "astral-session", autostart: false },
    overview: { path: "astral-overview", autostart: false },
    shortcuts: { path: "astral-shortcuts", autostart: false },
    polkit: { path: "astral-polkit", autostart: true }
  })

  function modulePath(name: string): string {
    const path = modules[name].path;
    return path.startsWith("/") ? path : Quickshell.shellDir + "/" + path;
  }
  function startModule(name: string): void {
    if (modules[name].autostart) starters[name].running = true;
  }

  Component.onCompleted: {
    startModule("bar");
    startModule("launcher");
    startModule("wallpaper");
    startModule("clipboard");
    startModule("polkit");
  }

  property var starters: ({
    bar: barStart,
    launcher: launcherStart,
    wallpaper: wallpaperStart,
    clipboard: clipboardStart,
    polkit: polkitStart
  })

  Process {
    id: barStart
    command: ["bash", root.modulePath("bar") + "/session.sh", "daemon"]
    onExited: (code, status) => { if (code !== 0 || status !== 0) console.error("Could not start astral-bar."); }
  }
  Process {
    id: launcherStart
    command: ["bash", root.modulePath("launcher") + "/session.sh", "daemon"]
    onExited: (code, status) => { if (code !== 0 || status !== 0) console.error("Could not start astral-launcher."); }
  }
  Process {
    id: wallpaperStart
    command: ["bash", root.modulePath("wallpaper") + "/session.sh", "daemon"]
    onExited: (code, status) => { if (code !== 0 || status !== 0) console.error("Could not start astral-wallpaper."); }
  }
  Process {
    id: clipboardStart
    command: ["bash", root.modulePath("clipboard") + "/session.sh", "daemon"]
    onExited: (code, status) => { if (code !== 0 || status !== 0) console.error("Could not start astral-clipboard."); }
  }
  Process {
    id: polkitStart
    command: ["bash", root.modulePath("polkit") + "/session.sh", "daemon"]
    onExited: (code, status) => { if (code !== 0 || status !== 0) console.error("Could not start astral-polkit."); }
  }
}
