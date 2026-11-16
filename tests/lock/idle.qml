import QtQuick
import Quickshell
import "astral-lock" as Lock

ShellRoot {
  id: root
  property int stage: 0
  property int ticks: 0
  property int waitTicks: 0
  function check(value, label) { if (!value) { console.error("IDLE_FAIL " + label); Qt.exit(1); } }
  Lock.IdleService { id: service }
  Lock.SleepGuard { id: guard }
  Timer {
    interval: 80; running: true; repeat: true
    onTriggered: {
      if (++root.ticks > 100) root.check(false, "timeout at " + root.stage);
      if (root.stage === 0) {
        if (!guard.sessionPath || !guard.testInhibitor.running) return;
        guard.event("signal path=/org/freedesktop/login1; interface=org.freedesktop.login1.Manager; member=PrepareForSleep");
        guard.event("   boolean true");
        root.check(guard.preparing && guard.testInhibitor.stdinEnabled, "delay held before secure lock");
        root.stage++;
      } else if (root.stage === 1) {
        if (guard.testInhibitor.running) return;
        root.check(guard.preparing && !guard.testInhibitor.stdinEnabled, "secure compositor releases delay");
        guard.event("signal path=/org/freedesktop/login1; interface=org.freedesktop.login1.Manager; member=PrepareForSleep");
        guard.event("   boolean false");
        root.stage++;
      } else if (root.stage === 2) {
        if (!guard.testInhibitor.running) return;
        root.check(!guard.preparing && guard.testInhibitor.stdinEnabled, "resume rearms inhibitor");
        guard.event("signal path=/org/freedesktop/login1/session/other; interface=org.freedesktop.login1.Session; member=Lock");
        guard.event("signal path=/org/freedesktop/login1/session/test; interface=org.freedesktop.login1.Session; member=Unlock");
        root.stage++;
      } else if (root.stage === 3) {
        if (++root.waitTicks < 4) return;
        root.check(!guard.preparing && guard.testInhibitor.running, "unrelated lock/unlock signals retain delay");
        console.log("IDLE_PASS");
        Qt.quit();
      }
    }
  }
}
