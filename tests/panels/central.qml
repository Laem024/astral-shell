pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "astral-bar/panel" as Panel
import "astral-bar/settings" as Settings
import "common" as Design

Scope {
  id: root
  property int stage: 0
  property int failures: 0
  readonly property var sizes: [[760, 760], [600, 680], [420, 580], [760, 760]]
  QtObject {
    id: settings
    property var value: Object.assign({}, Settings.SettingsData.value, {animations: false, mode: "dark"})
  }
  Design.Theme { id: theme; settings: settings }
  FloatingWindow {
    id: window
    visible: true
    implicitWidth: root.sizes[Math.floor(root.stage / 7)][0]
    implicitHeight: root.sizes[Math.floor(root.stage / 7)][1]
    Rectangle {
      id: scene
      anchors.fill: parent
      color: theme.surface
      Panel.PanelContent {
        id: panel
        anchors.fill: parent
        anchors.margins: 16
        tokens: theme
        settings: settings
        tab: categories[root.stage % 7].key
        onTabSelected: name => tab = name
      }
    }
  }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) {
      const result = find(child, name);
      if (result) return result;
    }
    return null;
  }
  function check(condition, message) {
    if (!condition) { failures++; console.log("CENTRAL_PANEL_FAIL", stage, panel.tab, message); }
  }
  function advance() {
    if (stage === 27) {
      console.log(failures ? "CENTRAL_PANEL_FAIL" : "CENTRAL_PANEL_PASS", "7 categories, 3 sizes, dark and light");
      Qt.quit();
    } else {
      stage++;
      if (stage === 21) settings.value = Object.assign({}, settings.value, {mode: "light"});
    }
  }
  Timer {
    id: checks
    interval: 220; running: true; repeat: true
    onTriggered: {
      const categories = root.find(panel, "panelCategories");
      root.check(!!categories, "navigation exists");
      for (const category of panel.categories) {
        const button = root.find(categories, "panelCategory-" + category.key);
        const position = button.mapToItem(categories, 0, 0);
        root.check(button.height > 0 && position.y >= 0 && position.y + button.height <= categories.height + 1, "navigation fits: " + category.key);
      }
      const loader = root.find(panel, "centralPageLoader");
      root.check(!!loader.item, "category loads");
      root.check(loader.width > 200 && loader.height > 150, "usable content area");
      const account = root.find(panel, "panelAccount");
      root.check(account.height > 0, "profile is visible");
      const output = Quickshell.env("ASTRAL_PANEL_SNAPSHOTS");
      if (output && root.stage < 7) {
        const path = output + "/panel-" + root.stage + ".png";
        checks.stop();
        scene.grabToImage(result => {
          result.saveToFile(path);
          root.advance();
          checks.start();
        });
      } else root.advance();
    }
  }
}
