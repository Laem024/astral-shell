import QtQuick
import Quickshell

// The user manager owns application processes and output across shell reloads.
QtObject {
  id: root
  readonly property bool pending: request.pending
  property Command request: Command { timeout: 10000 }
  function launch(command, directory, done) {
    if (pending) return false;
    if (!Array.isArray(command) || !command.length || !command[0] || command.some(arg => typeof arg !== "string" || arg.includes("\0"))) {
      if (done) done(false, "Invalid application arguments.");
      return false;
    }
    let args = ["systemd-run", "--user", "--collect", "--quiet", "--service-type=exec", "--property=ExitType=cgroup", "--expand-environment=no"];
    for (const name of ["PATH", "HOME", "WAYLAND_DISPLAY", "DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS", "PULSE_SERVER", "PIPEWIRE_RUNTIME_DIR", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_DATA_DIRS", "XDG_STATE_HOME", "XDG_CACHE_HOME"])
      if (Quickshell.env(name)) args.push("--setenv=" + name + "=" + Quickshell.env(name));
    if (directory) {
      if (!directory.startsWith("/") || directory.includes("\0")) { if (done) done(false, "Invalid working directory."); return false; }
      args.push("--working-directory=" + directory);
    }
    request.run(args.concat(["--"], command), (code, output, error) => { if (done) done(code === 0, error || "Application launch request failed."); });
    return true;
  }
}
