pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Decorative surfaces ignore exclusive zones so every piece reaches the physical
// output edge. A separate, transparent surface owns each edge's reservation.
Scope {
  id: root
  required property ShellScreen monitor
  required property FrameGeometry geometry
  required property string edge
  required property color surfaceColor
  readonly property bool horizontal: edge === "top" || edge === "bottom"
  readonly property bool curved: horizontal === !geometry.vertical
  readonly property real base: geometry.base(edge)
  readonly property real depth: base + (curved ? geometry.radius : 0)
  PanelWindow {
    screen: root.monitor
    visible: root.geometry.active && root.base > 0
    color: "transparent"
    anchors {
      top: root.edge !== "bottom"
      bottom: root.edge !== "top"
      left: root.edge !== "right"
      right: root.edge !== "left"
    }
    implicitWidth: root.depth
    implicitHeight: root.depth
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "astral-frame"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    FrameDrawing {
      anchors.fill: parent
      geometry: root.geometry
      edge: root.edge
      surfaceColor: root.surfaceColor
    }
  }
  PanelWindow {
    screen: root.monitor
    // The main edge also reserves the floating bar and its saved margin.
    visible: root.geometry.reservation(root.edge) > 0
    color: "transparent"
    anchors {
      top: root.edge !== "bottom"
      bottom: root.edge !== "top"
      left: root.edge !== "right"
      right: root.edge !== "left"
    }
    implicitWidth: 1
    implicitHeight: 1
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.geometry.reservation(root.edge)
    WlrLayershell.namespace: "astral-frame-reservation"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
  }
}
