pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design

ShellRoot {
  id: root
  QtObject { id: config; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: config }
  Panel.PanelState { id: navigation }
  Panel.NotificationPopups { settings: config; tokens: theme }
  property var previousToplevel: null
  property bool opened: false
  property int closes: 0
  // This parent reserves no space and cannot receive input.
  // qmllint disable uncreatable-type
  PanelWindow {
    id: parentWindow
    anchors { top: true; left: true; right: true }
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "astral-notification-focus-test"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    color: "transparent"
  }
  Item { id: owner; width: 240; height: 64 }
  Panel.NativePanel {
    id: panel
    settings: config; tokens: theme
    navigation: navigation; owner: owner; barWindow: parentWindow
    onVisibleChanged: if (root.opened && !visible) root.closes++
  }
  IpcHandler {
    target: "test"
    function inspect(stage: string): string {
      if (stage === "ready") {
        const surfaces = Data.NotificationData.surfaces;
        if (surfaces.length < 1) return "FAIL missing notification surface";
        for (const surface of surfaces) {
          if (!surface.visible || surface.exclusionMode !== ExclusionMode.Ignore
              || surface.WlrLayershell.keyboardFocus !== WlrKeyboardFocus.None)
            return "FAIL notification surface policy";
          if (surface.margins.top !== (config.value.position === "top" ? theme.horizontalSize * theme.scale + config.value.margin : 0) + 12 * theme.scale) return "FAIL double bar spacing";
        }
        root.previousToplevel = ToplevelManager.activeToplevel;
      } else if (stage === "arrival") {
        if (ToplevelManager.activeToplevel !== root.previousToplevel) return "FAIL active window changed on arrival";
        Data.NotificationData.clear();
      } else if (stage === "open") {
        root.opened = true;
        navigation.owner = owner;
        navigation.destination = "Notifications";
      } else if (stage === "opened") {
        if (!panel.visible || root.closes > 0) return "FAIL panel did not open";
        const grab = Array.from(panel.data).find(object => object.objectName === "panelFocusGrab");
        if (!grab || !grab.active) return "FAIL panel input group inactive";
        root.previousToplevel = ToplevelManager.activeToplevel;
      } else if (stage === "panel") {
        if (!panel.visible || root.closes > 0 || navigation.destination !== "Notifications" || navigation.owner !== owner) return "FAIL panel dismissed or changed";
        if (ToplevelManager.activeToplevel !== root.previousToplevel) return "FAIL active window changed with panel open";
        for (const popup of Data.NotificationData.popups.slice()) Data.NotificationData.hide(popup.id);
      } else if (stage === "hidden") {
        if (!panel.visible || root.closes > 0) return "FAIL panel dismissed when hiding notification";
      } else if (stage === "quiet") {
        Data.NotificationData.dnd = true;
        if (!panel.visible || root.closes > 0) return "FAIL panel dismissed on DND";
      } else return "FAIL unknown stage";
      return "PASS " + stage;
    }
  }
}
