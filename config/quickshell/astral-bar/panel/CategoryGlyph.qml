pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Native line icons stay crisp at every shared shell scale.
Shape {
  id: root
  property string kind: "connections"
  property color ink: "white"
  implicitWidth: 24
  implicitHeight: 24
  preferredRendererType: Shape.CurveRenderer
  Accessible.ignored: true
  ShapePath {
    strokeColor: root.ink
    strokeWidth: 1.6
    fillColor: "transparent"
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
    PathSvg {
      path: ({
        calendar: "M5 5 H19 Q21 5 21 7 V19 Q21 21 19 21 H5 Q3 21 3 19 V7 Q3 5 5 5 M3 10 H21 M8 3 V7 M16 3 V7 M8 14 H9 M15 14 H16 M8 17 H9",
        music: "M9 17 V5 L20 3 V15 M9 8 L20 6 M9 17 C9 21 3 22 3 18 C3 15 9 14 9 17 M20 15 C20 19 14 20 14 16 C14 13 20 12 20 15",
        connections: "M3 7 A14 14 0 0 1 21 7 M6 11 A9 9 0 0 1 18 11 M9 15 A4.5 4.5 0 0 1 15 15 M12 19 H12.01",
        bolt: "M13 2 L4 14 H11 L10 22 L20 9 H13 Z",
        screen: "M5 3 H19 Q21 3 21 5 V15 Q21 17 19 17 H5 Q3 17 3 15 V5 Q3 3 5 3 M12 17 V21 M8 21 H16 M7 7 H10 M7 7 V10 M17 13 H14 M17 13 V10",
        sound: "M4 9 H8 L13 5 V19 L8 15 H4 Z M17 8 Q21 12 17 16 M20 5 Q26 12 20 19",
        power: "M12 2 V11 M6 5 A9 9 0 1 0 18 5",
        notifications: "M5 17 H19 L17 14 V9 A5 5 0 0 0 7 9 V14 Z M10 21 H14 M12 2 V4",
        edit: "M4 16 L16 4 L20 8 L8 20 H4 Z M13 7 L17 11",
        check: "M5 12 L10 17 L19 7"
      })[root.kind] || "M5 12 H19 M12 5 V19"
    }
  }
}
