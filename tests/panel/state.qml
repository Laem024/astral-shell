import QtQuick
import Quickshell
import "../../config/quickshell/astral-bar/panel" as Panel

// Mirrors the real panel: losing every visible source hides the layer surface,
// and NativePanel's visibility handler then closes the navigation state.
Scope {
  id: root
  property int closes: 0
  property int status: 0
  readonly property bool panelVisible: navigation.owner !== null
    && (navigation.destination !== "" || navigation.tray || navigation.windowMenu)
  onPanelVisibleChanged: {
    if (!panelVisible && navigation.owner !== null) {
      closes++;
      navigation.close();
    }
  }

  Panel.PanelState { id: navigation }
  QtObject { id: monitorA }
  QtObject { id: monitorB }
  QtObject { id: clockAnchor; property real width: 96; property real height: 40 }
  QtObject { id: focusAnchor; property real width: 520; property real height: 40 }

  function check(ok, message) {
    if (!ok) {
      root.status = 1;
      console.error("PANEL_FAIL: " + message);
    }
  }

  // Quickshell connects its quit handler after Component.onCompleted.
  Timer { interval: 50; running: true; onTriggered: Qt.exit(root.status) }

  Component.onCompleted: {
    navigation.toggle("Control Center", monitorA, clockAnchor);
    check(root.panelVisible && root.closes === 0, "central panel is visible");

    // The surface must not lose every visible source during the switch, or its
    // visibility handler closes the menu and drops the fresh anchor.
    navigation.toggleWindowMenu(monitorA, focusAnchor);
    check(navigation.windowMenu && navigation.owner === monitorA, "focus menu owns the surface");
    check(navigation.anchor === focusAnchor, "focus menu keeps its anchor");
    check(root.closes === 0, "switching to the focus menu does not hide the surface");

    navigation.toggleWindowMenu(monitorA, focusAnchor);
    check(navigation.owner === null && !navigation.windowMenu, "second activation closes the focus menu");

    navigation.anchor = clockAnchor;
    navigation.openTray(monitorA);
    check(root.panelVisible && root.closes === 0, "tray is visible");
    navigation.toggleWindowMenu(monitorA, focusAnchor);
    check(navigation.windowMenu && navigation.anchor === focusAnchor && root.closes === 0,
      "focus menu takes over from the tray without hiding");

    navigation.toggleWindowMenu(monitorA, focusAnchor);
    navigation.toggleWindowMenu(monitorB, focusAnchor);
    check(navigation.owner === monitorB && navigation.anchor === focusAnchor,
      "focus menu moves across monitors with its anchor");

    if (root.status === 0)
      console.log("PANEL_QML_PASS (central panel, focus menu anchor, tray hand-off, cross-monitor ownership)");
  }
}
