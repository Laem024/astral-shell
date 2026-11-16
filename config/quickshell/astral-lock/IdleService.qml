import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common" as Common

// Native idle notifications replace swayidle and shell worker scripts.
ShellRoot {
  id: root
  property bool idle: false
  property bool suspended: false
  readonly property var settings: Common.SettingsData.value.idle
  Component.onCompleted: Quickshell.watchFiles = false
  // Separate requests keep equal timeout settings from dropping an action.
  Common.Command { id: lockCommand; timeout: 15000 }
  Common.Command { id: screenCommand }
  Common.Command { id: command; timeout: 45000 }
  IdleMonitor {
    enabled: root.settings.enabled
    timeout: root.settings.lockSeconds
    respectInhibitors: true
    onIsIdleChanged: if (isIdle && !lockCommand.running) lockCommand.run(["astral-lock", "auto-lock"], () => {})
  }
  IdleMonitor {
    id: screenIdle
    enabled: root.settings.enabled
    timeout: root.settings.screenOffSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle && !screenCommand.running) screenCommand.run(["astral-lock", "auto-dpms"], () => {
        // Activity may arrive while the serialized power request is starting.
        if (!screenIdle.isIdle) root.wakeScreen();
      });
      else if (!isIdle) root.wakeScreen();
    }
  }
  Common.Command { id: wake }
  function wakeScreen() { if (!wake.running) wake.run(["hyprctl", "dispatch", "dpms", "on"], () => {}); }
  SleepGuard {}
  IdleMonitor {
    enabled: root.settings.enabled
    timeout: root.settings.suspendSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      root.idle = isIdle;
      if (!isIdle) root.suspended = false;
      else root.check();
    }
  }
  function check() {
    if (idle && !suspended && !command.running) {
      command.run(["astral-lock", "auto-suspend"], (code, output) => {
        if (code === 0 && !output.includes("blocked")) suspended = true;
      });
    }
  }
  Timer { interval: 30000; repeat: true; running: root.idle && !root.suspended; onTriggered: root.check() }
  IpcHandler {
    target: "idle"
    function state(): string { return "ready"; }
    function active(): string { return root.idle ? "true" : "false"; }
    function begin(): string { root.idle = true; root.suspended = false; root.check(); return "ok"; }
    function cancel(): string { root.idle = false; root.suspended = false; return "ok"; }
  }
}
