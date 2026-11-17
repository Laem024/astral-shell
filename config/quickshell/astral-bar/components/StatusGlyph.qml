import QtQuick
import QtQuick.Shapes

// Solid silhouettes for the system dock, drawn independently of icon fonts.
Item {
  id: root
  required property color ink
  property string kind: "tray"
  property real level: 1
  property bool muted: false
  property bool charging: false
  implicitWidth: 24
  implicitHeight: 24
  Accessible.ignored: true
  Item {
    width: 24; height: 24
    anchors.centerIn: parent
    scale: Math.min(root.width, root.height) / 24
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: "transparent"
        fillColor: root.ink
        PathSvg {
          path: root.kind === "audio" ? "M3 9 H7 L13 4.5 Q14 4 14 5.5 V18.5 Q14 20 13 19.5 L7 15 H3 Q2 15 2 14 V10 Q2 9 3 9 Z"
            : root.kind === "notifications" ? "M12 2 A1.5 1.5 0 0 1 13.5 3.5 V4 Q18 5 18 10 V13 Q18 15 20 16.5 V18 H4 V16.5 Q6 15 6 13 V10 Q6 5 10.5 4 V3.5 A1.5 1.5 0 0 1 12 2 Z M9 20 H15 A3 3 0 0 1 9 20 Z"
            : root.kind === "tray" ? "M4 4 H10 V10 H4 Z M14 4 H20 V10 H14 Z M4 14 H10 V20 H4 Z M14 14 H20 V20 H14 Z"
            : root.kind === "ethernet" ? "M6 3 H18 Q20 3 20 5 V15 H15 V18 H9 V15 H4 V5 Q4 3 6 3 Z M6 20 H18 V22 H6 Z"
            : ""
        }
      }
      ShapePath {
        strokeColor: "transparent"
        fillColor: Qt.alpha(root.ink, root.level > 0.6 ? 1 : 0.2)
        PathSvg { path: root.kind === "wifi" ? "M1.5 8 Q12 0 22.5 8 L20 10.5 Q12 4.5 4 10.5 Z" : "" }
      }
      ShapePath {
        strokeColor: "transparent"
        fillColor: Qt.alpha(root.ink, root.level > 0.25 ? 1 : 0.2)
        PathSvg { path: root.kind === "wifi" ? "M6 12.5 Q12 7.7 18 12.5 L15.5 15 Q12 12.3 8.5 15 Z" : "" }
      }
      ShapePath {
        strokeColor: "transparent"
        fillColor: root.ink
        PathSvg { path: root.kind === "wifi" ? "M10 17 Q12 15.5 14 17 L12 19.5 Z" : "" }
      }
      ShapePath {
        strokeWidth: 2
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        strokeColor: root.ink
        fillColor: "transparent"
        PathSvg {
          path: root.kind === "battery" ? "M4 6 H18 Q20 6 20 8 V16 Q20 18 18 18 H4 Q2 18 2 16 V8 Q2 6 4 6 Z M23 10 V14"
            : root.kind === "audio" ? (root.muted ? "M18 9 L23 15 M23 9 L18 15"
              : "M18 8 Q22 12 18 16" + (root.level > 0.5 ? " M21 5 Q27 12 21 19" : ""))
            : root.kind === "off" ? "M12 3 V11 M6 6 A9 9 0 1 0 18 6"
            : root.kind === "disconnected" || root.kind === "unavailable" ? "M4 4 L20 20 M3 9 Q12 2 21 9 M7 13 Q12 9 17 13 M11 18 H13"
            : ""
        }
      }
    }
    Rectangle {
      visible: root.kind === "battery" && !root.charging
      x: 5; y: 9; height: 6; radius: 1
      width: Math.max(0, Math.min(1, root.level)) * 12
      color: root.ink
    }
    Shape {
      anchors.fill: parent
      visible: root.kind === "battery" && root.charging
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: "transparent"
        fillColor: root.ink
        PathSvg { path: "M13 7 L8 13 H11 L10 17 L15 11 H12 Z" }
      }
    }
  }
}
