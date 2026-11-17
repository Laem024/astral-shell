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
        bar: "M3 4 H21 V9 H3 Z M5 6 H7 M10 6 H14 M17 6 H19 M3 14 H21 M3 19 H21",
        keyboard: "M3 6 H21 V18 H3 Z M6 9 H7 M10 9 H11 M14 9 H15 M18 9 H18.1 M6 12 H7 M10 12 H11 M14 12 H15 M18 12 H18.1 M7 15 H17",
        mouse: "M6 9 A6 6 0 0 1 18 9 V15 A6 6 0 0 1 6 15 Z M12 3 V10 M6 10 H18",
        palette: "M12 3 C6 3 3 7 3 12 C3 18 7 21 12 21 C16 21 12 16 16 16 H18 C23 16 22 8 18 5 Q15 3 12 3 M7 9 H7.1 M11 6 H11.1 M16 7 H16.1 M18 11 H18.1 M6 14 H6.1",
        sliders: "M4 6 H8 M12 6 H20 M4 12 H14 M18 12 H20 M4 18 H6 M10 18 H20 M8 3 V9 M14 9 V15 M6 15 V21",
        info: "M12 3 A9 9 0 1 0 12 21 A9 9 0 1 0 12 3 M12 10 V17 M12 7 H12.01",
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
