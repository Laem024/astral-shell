pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Geometry polling exists only while the menu is open; one process at a time.
Scope {
  id: root
  required property bool opened
  property var ownerScreen: null
  property rect contentRect: Qt.rect(0, 0, 0, 0)
  property rect controlRect: Qt.rect(0, 0, 0, 0)
  property var surfaces: []
  property string focusedAddress: ""
  property string snapshot: ""
  property int generation: 0
  property int requestGeneration: -1
  signal dismiss()
  function event(name, data) {
    // activewindow also fires when the current client's title changes.
    if (name === "activewindow") return;
    if (name === "activewindowv2" && typeof data === "string" && data.replace(/^0x/, "") === focusedAddress) return;
    // Layer surfaces can temporarily clear the active client when taking focus.
    if (["activewindow", "activewindowv2"].includes(name) && (data === "" || data === ",")) return;
    if (opened && ["workspace", "workspacev2", "focusedmon", "activewindow", "activewindowv2", "movewindow", "movewindowv2", "resizeactive", "moveactive", "openwindow", "closewindow", "monitorremoved"].includes(name)) dismiss();
  }
  onOpenedChanged: {
    generation++; snapshot = "";
    focusedAddress = Hyprland.activeToplevel ? Hyprland.activeToplevel.address.replace(/^0x/, "") : "";
    if (opened) poll();
  }
  function poll() {
    if (!opened || probe.running) return;
    requestGeneration = generation; probe.running = true;
  }
  Loader {
    // The source is loaded lazily so event tests need no Wayland backend.
    source: root.opened && root.ownerScreen ? Qt.resolvedUrl("PopupShield.qml") : ""
    // qmllint disable missing-property
    onLoaded: item.policy = root
    // qmllint enable missing-property
  }
  Connections {
    target: Hyprland
    function onRawEvent(event: HyprlandEvent) { root.event(event.name, event.data); }
  }
  Timer { interval: 200; running: root.opened; repeat: true; onTriggered: root.poll() }
  Process {
    id: probe
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector { id: output }
    stderr: StdioCollector {}
    onExited: (code, status) => {
      if (!root.opened || root.requestGeneration !== root.generation || code !== 0 || status !== 0) return;
      try {
        const windows = JSON.parse(output.text).map(w => [w.address, w.at, w.size, w.monitor, w.workspace.id]).sort((a,b) => String(a[0]).localeCompare(String(b[0])));
        const next = JSON.stringify(windows);
        if (root.snapshot && root.snapshot !== next) root.dismiss();
        root.snapshot = next;
      } catch (_) {}
    }
  }
}
