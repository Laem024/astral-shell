import QtQuick
import QtQuick.Shapes

// Original Astral symbols on a shared 24px canvas. No icon font dependency.
Item {
  id: root
  required property color ink
  property string kind: "grid"
  property real level: 1
  property bool muted: false
  implicitWidth: 24
  implicitHeight: 24
  Accessible.ignored: true
  readonly property string outline: {
    switch (kind) {
    case "astral": return "M12 2 L14.8 9.2 L22 12 L14.8 14.8 L12 22 L9.2 14.8 L2 12 L9.2 9.2 Z";
    case "wifi": return (level > 0.6 ? "M3 8.5 Q12 1.5 21 8.5 " : "") + (level > 0.25 ? "M6.5 12 Q12 7.5 17.5 12 " : "") + "M10 15.5 Q12 14 14 15.5 M12 19 H12.01";
    case "ethernet": return "M4 4 H20 V17 H16 V21 H8 V17 H4 Z M8 8 V12 M12 8 V12 M16 8 V12";
    case "off": return "M12 3 V11 M6.3 5.8 A9 9 0 1 0 17.7 5.8";
    case "disconnected":
    case "unavailable": return "M9 8 L15 14 M15 8 L9 14 M5 3 H19 Q21 3 21 5 V17 Q21 19 19 19 H5 Q3 19 3 17 V5 Q3 3 5 3 Z M9 22 H15";
    case "audio": return "M4 9 H8 L13 5 V19 L8 15 H4 Z" + (muted ? " M17 9 L22 14 M22 9 L17 14" : " M17 9 Q20 12 17 15" + (level > 0.5 ? " M20 6 Q25 12 20 18" : ""));
    case "battery": return "M4 6 H18 Q20 6 20 8 V16 Q20 18 18 18 H4 Q2 18 2 16 V8 Q2 6 4 6 Z M23 10 V14";
    case "charging": return "M13 3 L7 13 H12 L11 21 L17 10 H12 Z";
    case "notifications": return "M5 16 Q7 14 7 10 V9 A5 5 0 0 1 17 9 V10 Q17 14 19 16 Z M10 20 Q12 22 14 20 M12 2 V4";
    case "window": return "M5 4 H19 Q21 4 21 6 V18 Q21 20 19 20 H5 Q3 20 3 18 V6 Q3 4 5 4 Z M3 9 H21 M7 6.5 H7.01";
    case "capture": return "M8 5 L9.5 3 H14.5 L16 5 H19 Q21 5 21 7 V18 Q21 20 19 20 H5 Q3 20 3 18 V7 Q3 5 5 5 Z M16 12.5 A4 4 0 1 1 8 12.5 A4 4 0 1 1 16 12.5";
    case "tray": return "M6 9 L12 15 L18 9";
    case "browser": return "M21 12 A9 9 0 1 1 3 12 A9 9 0 1 1 21 12 M3 12 H21 M12 3 C7 8 7 16 12 21 C17 16 17 8 12 3";
    case "code": return "M8 7 L3 12 L8 17 M16 7 L21 12 L16 17 M14 4 L10 20";
    case "folder": return "M3 8 V6 Q3 4 5 4 H10 L13 7 H19 Q21 7 21 9 V18 Q21 20 19 20 H5 Q3 20 3 18 Z M3 10 H21";
    case "chat": return "M5 4 H19 Q21 4 21 6 V15 Q21 17 19 17 H10 L5 21 V17 Q3 17 3 15 V6 Q3 4 5 4 Z M7 9 H17 M7 13 H13";
    case "play": return "M8 5 L19 12 L8 19 Z";
    case "pause": return "M8 5 V19 M16 5 V19";
    case "next": return "M5 6 L15 12 L5 18 Z M19 6 V18";
    case "previous": return "M19 6 L9 12 L19 18 Z M5 6 V18";
    case "music": return "M10 17 V5 L20 3 V15 M10 8 L20 6 M10 17 A3 3 0 1 1 7 14 Q10 14 10 17 M20 15 A3 3 0 1 1 17 12 Q20 12 20 15";
    default: return "M4 4 H10 V10 H4 Z M14 4 H20 V10 H14 Z M4 14 H10 V20 H4 Z M14 14 H20 V20 H14 Z";
    }
  }
  Item {
    width: 24; height: 24
    anchors.centerIn: parent
    scale: Math.min(root.width, root.height) / 24
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: root.ink
        strokeWidth: root.kind === "astral" ? 0.6 : 1.65
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        fillColor: root.kind === "astral" ? root.ink : root.kind === "play" ? Qt.alpha(root.ink, 0.18) : "transparent"
        PathSvg { path: root.kind === "astral" ? "" : root.outline }
      }
      // One light direction and a symmetric inset keep the star legible.
      ShapePath {
        strokeColor: Qt.lighter(root.ink, 1.25)
        strokeWidth: 0.6
        joinStyle: ShapePath.RoundJoin
        fillGradient: LinearGradient {
          x1: 5; y1: 3; x2: 18; y2: 22
          GradientStop { position: 0; color: Qt.lighter(root.ink, 1.45) }
          GradientStop { position: 0.45; color: root.ink }
          GradientStop { position: 1; color: Qt.darker(root.ink, 1.4) }
        }
        PathSvg { path: root.kind === "astral" ? root.outline : "" }
      }
      ShapePath {
        strokeColor: Qt.alpha(Qt.lighter(root.ink, 1.6), 0.65)
        strokeWidth: 0.55
        joinStyle: ShapePath.RoundJoin
        fillColor: "transparent"
        PathSvg {
          path: root.kind === "astral"
            ? "M12 5.5 L14 10 L18.5 12 L14 14 L12 18.5 L10 14 L5.5 12 L10 10 Z" : ""
        }
      }
    }
  }
}
