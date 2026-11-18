import QtQuick
import QtQuick.Window
import QtTest
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
  property bool naturalSize: false
  property int naturalWidth: 820
  property int closeRequests: 0

  function check(condition, label) {
    if (!condition) { console.error("SESSION_FAIL: " + label); Qt.exit(1); }
  }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
    return null;
  }
  function next(value) { root.step = value; root.stepTicks = 0; }
  function done(action) { return root.completed.indexOf(action) !== -1; }

  QtObject { id: config; property var value: Common.SettingsData.value }
  Common.Theme { id: theme; settings: config }
  Session.SessionMenu { id: menu; tokens: theme }
  Window {
    id: testWindow
    visible: true
    width: 900
    height: 700
    TestCase { id: keyboard; when: false }
    Session.SessionContent {
      id: content
      tokens: theme
      active: true
      width: root.naturalSize ? root.naturalWidth : 520
      height: root.naturalSize ? implicitHeight : 430
      onCloseRequested: root.closeRequests++
    }
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
        const viewport = root.find(content, "sessionActionScroll");
        root.check(viewport.contentHeight > viewport.height, "narrow menu wraps and scrolls vertically");
        content.focusTile(content.actions.length - 1);
        root.check(viewport.contentY > 0, "keyboard selection reveals last action");
        content.focusTile(0);
        root.check(viewport.contentY === 0, "keyboard selection reveals first action");
        root.naturalSize = true;
        testWindow.requestActivate();
        root.next(10);
      } else if (root.step === 10) {
        const viewport = root.find(content, "sessionActionScroll");
        root.check(viewport.height >= viewport.contentHeight, "natural height shows complete cards without scrolling");
        content.reset();
        root.check(content.activeFocus && content.focusIndex === 0, "reset focuses first action");
        keyboard.keyClick(Qt.Key_Right);
        root.check(content.focusIndex === 1, "Right selects next card");
        keyboard.keyClick(Qt.Key_Left);
        root.check(content.focusIndex === 0, "Left selects previous card");
        keyboard.keyClick(Qt.Key_Left);
        root.check(content.focusIndex === content.actions.length - 1, "Left wraps to last card");
        keyboard.keyPress(Qt.Key_Return);
        root.check(content.holding === "poweroff", "Enter starts confirmation on focused card");
        keyboard.keyRelease(Qt.Key_Return);
        root.check(content.holding === "", "Enter release cancels confirmation");
        keyboard.keyPress(Qt.Key_Space);
        root.check(content.holding === "poweroff", "Space starts confirmation on focused card");
        keyboard.keyRelease(Qt.Key_Space);
        root.check(content.holding === "", "Space release cancels confirmation");
        keyboard.keyClick(Qt.Key_Escape);
        root.check(root.closeRequests === 1, "Escape closes from a focused card");
        root.naturalWidth = 520;
        root.next(11);
      } else if (root.step === 11) {
        const viewport = root.find(content, "sessionActionScroll");
        root.check(viewport.height >= viewport.contentHeight, "three-column layout shows full cards without scrolling");
        content.reset();
        keyboard.keyClick(Qt.Key_Down);
        root.check(content.focusIndex === 3, "Down selects next row");
        keyboard.keyClick(Qt.Key_Up);
        root.check(content.focusIndex === 0, "Up selects previous row");
        keyboard.keyClick(Qt.Key_Tab);
        root.check(content.focusIndex === 1, "Tab selects next card");
        root.naturalWidth = 360;
        root.next(12);
      } else if (root.step === 12) {
        const viewport = root.find(content, "sessionActionScroll");
        root.check(viewport.height >= viewport.contentHeight, "two-column layout shows full cards without scrolling");
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
