import QtQuick
import Quickshell
import "../../config/quickshell/astral-session" as Session
import "../../config/quickshell/astral-session/Logic.js" as Logic
import "../../config/quickshell/common" as Common

ShellRoot {
  id: root
  property int step: 0
  property int stepTicks: 0
  property int ticks: 0
  property var completed: []

  function check(condition, label) {
    if (!condition) { console.error("SESSION_FAIL: " + label); Qt.exit(1); }
  }
  function next(value) { root.step = value; root.stepTicks = 0; }
  function done(action) { return root.completed.indexOf(action) !== -1; }

  QtObject { id: config; property var value: Common.SettingsData.value }
  Common.Theme { id: theme; settings: config }
  Session.SessionMenu { id: menu; tokens: theme }
  Session.SessionContent {
    id: content
    tokens: theme
    active: true
    width: 520
    height: 430
  }
  Connections {
    target: Common.SessionActions
    function onCompleted(action) { root.completed.push(action); }
  }

  Timer {
    interval: 50
    repeat: true
    running: true
    onTriggered: {
      root.ticks++;
      root.stepTicks++;
      root.check(root.ticks < 400, "timeout step " + root.step);
      if (root.step === 0) {
        if (!Common.SessionActions.ready) return;
        root.check(!Common.SessionActions.blocked, "idle privacy is not blocked");
        menu.toggle(null);
        root.check(menu.opened, "menu opens on an available monitor");
        menu.close();
        root.check(!menu.opened, "menu closes");
        root.check(Logic.actions.length === 5, "five actions");
        root.check(Logic.requiresHold("logout") && Logic.requiresHold("reboot")
          && Logic.requiresHold("poweroff"), "hold actions are marked");
        root.check(!Logic.requiresHold("lock") && !Logic.requiresHold("suspend"), "immediate actions are marked");
        root.check(Logic.shortcutAction("r") === "reboot" && Logic.shortcutAction("X") === "", "shortcut mapping");
        content.pressKey("r");
        root.check(content.holding === "reboot", "hold starts");
        root.check(!Common.SessionActions.pending && !root.done("reboot"), "hold waits for the timer");
        root.next(1);
      } else if (root.step === 1) {
        if (!root.done("reboot")) return;
        root.check(content.holding === "", "hold resets after trigger");
        content.pressKey("p");
        root.check(content.holding === "poweroff", "second hold starts");
        root.next(2);
      } else if (root.step === 2) {
        if (root.stepTicks < 4) return;
        content.releaseKey("p");
        root.check(content.holding === "", "release cancels the hold");
        root.next(3);
      } else if (root.step === 3) {
        if (root.stepTicks < 24) return;
        root.check(!root.done("poweroff"), "cancelled hold never runs");
        Common.SessionActions.perform("poweroff");
        root.check(Common.SessionActions.pending, "poweroff starts");
        root.next(4);
      } else if (root.step === 4) {
        if (Common.SessionActions.pending) return;
        root.check(Common.SessionActions.error.includes("simulated failure"), "action failure is reported");
        Common.SessionActions.perform("not-a-session-action");
        root.check(!Common.SessionActions.pending, "unknown actions are ignored");
        Common.SessionActions.perform("lock");
        root.check(Common.SessionActions.pending, "lock starts");
        root.next(5);
      } else if (root.step === 5) {
        if (Common.SessionActions.pending) return;
        root.check(root.done("lock"), "lock completes");
        console.log("SESSION_QML_PASS (actions, shortcuts, hold, cancel, failure, privacy)");
        Qt.quit();
      }
    }
  }
}
