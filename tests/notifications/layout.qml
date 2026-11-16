pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design
import "../../config/quickshell/astral-bar/modules" as Modules

ShellRoot {
  id: root
  QtObject { id: config; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: config }
  Modules.NotificationsModule { id: log; tokens: theme; count: Data.NotificationData.unread }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) {
      const found = find(child, name);
      if (found) return found;
    }
    return null;
  }
  FloatingWindow {
    id: popupWindow
    visible: true
    implicitWidth: 380; implicitHeight: 600
    Column {
      id: popupScene
      spacing: 10
      width: parent.width
      Repeater {
        model: Data.NotificationData.popups
        Panel.NotificationCard {
          required property var modelData
          width: parent.width
          tokens: theme; entry: modelData.entry; popup: true
        }
      }
    }
  }
  FloatingWindow {
    id: window
    visible: true
    implicitWidth: 320; implicitHeight: 600
    Rectangle {
      id: pageScene
      anchors.fill: parent
      color: theme.surface
      Panel.NotificationsPage { id: page; anchors.fill: parent; anchors.margins: 12; tokens: theme }
    }
  }
  IpcHandler {
    target: "test"
    function inspect(stage: string): string {
      if (stage === "page") {
        if (Data.NotificationData.entries.length !== 1 || Data.NotificationData.unread !== 0)
          return "FAIL page reader";
        return "PASS page";
      }
      if (stage === "hide-page") {
        page.visible = false;
        if (Data.NotificationData.readers !== 0) return "FAIL hidden page reader";
        return "PASS " + stage;
      }
      if (stage === "unread") {
        if (log.count !== 1 || root.find(log, "notifications").label !== "01") return "FAIL LOG unread count";
        if (root.find(page, "notificationHistoryCount").text !== "2 notifications") return "FAIL history count";
        page.visible = true;
        if (log.count !== 0 || root.find(log, "notifications").label !== "00") return "FAIL LOG read count";
        return "PASS " + stage;
      }
      if (stage === "quiet-on") {
        Data.NotificationData.dnd = true;
        if (!root.find(page, "notificationDndToggle").checked) return "FAIL DND enabled switch";
        if (Data.NotificationData.popups.length !== 0) return "FAIL DND popup suppression";
        return "PASS " + stage;
      }
      if (stage === "quiet-off") {
        Data.NotificationData.dnd = false;
        if (root.find(page, "notificationDndToggle").checked) return "FAIL DND disabled switch";
        return "PASS " + stage;
      }
      if (stage === "delete") {
        Data.NotificationData.remove(Data.NotificationData.entries[0].id);
        if (root.find(page, "notificationHistoryCount").text !== "1 notification") return "FAIL delete counter";
        return "PASS " + stage;
      }
      if (stage === "clear") {
        Data.NotificationData.clear();
        if (root.find(page, "notificationHistoryCount").text !== "0 notifications") return "FAIL clear counter";
        return "PASS " + stage;
      }
      if (stage === "file-preview") {
        Data.NotificationData.localFile("Recording saved", "/home/demo/Videos/ScreenRecordings/2026-11-11_11-30-00-ABC123.mkv");
        return "PASS " + stage;
      }
      if (stage === "file-snapshot") {
        const card = root.find(popupScene, "notificationCard");
        if (!card || !card.video || !card.canOpen) return "FAIL local video popup";
        const directory = Quickshell.env("ASTRAL_NOTIFICATION_SCREENSHOTS");
        if (directory) popupScene.grabToImage(result => result.saveToFile(directory + "/video-popup.png"));
        return "PASS " + stage;
      }
      if (stage === "snapshot") {
        const directory = Quickshell.env("ASTRAL_NOTIFICATION_SCREENSHOTS");
        if (directory) {
          pageScene.grabToImage(result => result.saveToFile(directory + "/history.png"));
          popupScene.grabToImage(result => result.saveToFile(directory + "/popup.png"));
        }
        return "PASS " + stage;
      }
      config.value = Object.assign({}, config.value, {position: stage.split("-")[0], mode: stage.split("-")[1]});
      return "PASS " + stage;
    }
  }
}
