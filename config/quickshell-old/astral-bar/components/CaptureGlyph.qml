pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

Shape {
  id: root
  property string kind: "capture"
  required property color ink
  // Shape recalculates its implicit bounds from the path. Keep the 24×24
  // coordinate canvas explicit so paths inset from the origin stay centered.
  width: 24
  height: 24
  implicitWidth: 24
  implicitHeight: 24
  preferredRendererType: Shape.CurveRenderer
  Accessible.ignored: true
  ShapePath {
    strokeColor: root.ink
    strokeWidth: 1.5
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
    fillColor: "transparent"
    PathSvg {
      path: root.kind === "monitor" ? "M4 4 H20 Q21 4 21 5 V16 Q21 17 20 17 H4 Q3 17 3 16 V5 Q3 4 4 4 Z M8 21 H16 M12 17 V21"
        : root.kind === "window" ? "M5 3 H19 Q21 3 21 5 V19 Q21 21 19 21 H5 Q3 21 3 19 V5 Q3 3 5 3 Z M3 8 H21 M6 5.5 H7"
        : root.kind === "region" ? "M9 3 H3 V9 M15 3 H21 V9 M21 15 V21 H15 M9 21 H3 V15 M10 12 H14 M12 10 V14"
        : "M8 4 H4 V8 M16 4 H20 V8 M20 16 V20 H16 M8 20 H4 V16 M16 12 A4 4 0 1 1 8 12 A4 4 0 1 1 16 12"
    }
  }
}
