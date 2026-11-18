import QtQuick
import QtTest
import "../../config/sddm/astral/components" as Components
import "../../config/sddm/astral/design" as Design

TestCase {
  id: test
  name: "SessionDropdown"
  width: 1280
  height: 1000
  visible: true
  when: windowShown
  property var keyboard: ({capsLock: false})
  ListModel { id: userModel; ListElement { name: "test"; realName: "Test" } }
  ListModel {
    id: sessionModel
    ListElement { name: "Hyprland"; comment: "Wayland" }
    ListElement { name: "Other desktop"; comment: "Wayland" }
  }
  Design.Theme { id: theme; values: ({}) }
  Components.LoginCard {
    id: card
    x: 300; y: 80
    width: implicitWidth; height: implicitHeight
    tokens: theme
    user: ({name: "test", realName: "Test"})
    userCount: 1; userIndex: 0
    session: ({name: "Hyprland"})
    sessionCount: 2; sessionIndex: 0
    onSessionSelected: index => { sessionIndex = index; }
  }
  function test_dropdown() {
    const selector = findChild(card, "sessionSelector");
    const popup = findChild(card, "sessionPopup");
    verify(selector !== null);
    verify(popup !== null);
    mouseClick(selector, selector.width / 2, selector.height / 2);
    tryCompare(popup, "opened", true);
    compare(popup.parent, selector);
    compare(popup.x, 0);
    compare(popup.y, selector.height + 8);
    // Check the actual overlay position, not just the popup's requested y.
    const top = popup.contentItem.mapToItem(test, 0, 0).y;
    const bottom = selector.mapToItem(test, 0, selector.height).y;
    verify(top >= bottom + 8, "sessions must open below their selector");
    keyClick(Qt.Key_Down);
    keyClick(Qt.Key_Return);
    tryCompare(card, "sessionIndex", 1);
    tryCompare(popup, "opened", false);
    mouseClick(selector, selector.width / 2, selector.height / 2);
    tryCompare(popup, "opened", true);
    keyClick(Qt.Key_Escape);
    tryCompare(popup, "opened", false);
  }
}
