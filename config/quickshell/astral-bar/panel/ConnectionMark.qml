pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../../common" as Design

// A single tinted sigil per connection kind, built from the same bar and line
// language as the bar instruments instead of an icon font.
Item {
  id: root
  required property Design.Theme tokens
  required property string kind
  property color accent: tokens.cyan
  property bool active: true
  property bool showStatus: false
  implicitWidth: 42
  implicitHeight: 42
  Accessible.ignored: true

  Rectangle {
    anchors.fill: parent
    radius: 10
    color: Qt.alpha(root.accent, root.active ? 0.1 : 0.035)
    border.color: Qt.alpha(root.accent, root.active ? 0.28 : 0.12)
  }

  Row {
    visible: root.kind === "wifi"
    anchors.centerIn: parent
    width: 25
    height: 17
    spacing: 2.5
    Repeater {
      model: [4, 7, 10, 13, 16]
      Rectangle {
        required property int index
        required property int modelData
        width: 3
        height: modelData
        y: 17 - height
        radius: 1.5
        color: root.active ? root.accent : Qt.alpha(root.tokens.muted, 0.7)
        opacity: index === 4 ? 1 : 0.45 + index * 0.13
      }
    }
  }

  Text {
    visible: root.kind === "bluetooth"
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -1
    text: "ᛒ"
    color: root.active ? root.accent : root.tokens.muted
    font { family: root.tokens.font; pixelSize: 23 }
  }

  Shape {
    visible: root.kind === "vpn"
    anchors.centerIn: parent
    width: 21
    height: 23
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.active ? root.accent : root.tokens.muted
      strokeWidth: 1.4
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M10.5 1 L20 4.5 V11.5 C20 17.3 10.5 22 10.5 22 C10.5 22 1 17.3 1 11.5 V4.5 Z" }
    }
    ShapePath {
      fillColor: root.active ? root.accent : root.tokens.muted
      strokeColor: "transparent"
      PathSvg { path: "M10.5 7.6 A2.3 2.3 0 0 1 11.6 11.9 L12.4 15.7 H8.6 L9.4 11.9 A2.3 2.3 0 0 1 10.5 7.6 Z" }
    }
  }

  Shape {
    visible: root.kind === "search"
    anchors.centerIn: parent
    width: 20
    height: 20
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.active ? root.accent : root.tokens.muted
      strokeWidth: 1.5
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M8.5 1.5 A7 7 0 1 0 8.5 15.5 A7 7 0 1 0 8.5 1.5 Z" }
    }
    ShapePath {
      strokeColor: root.active ? root.accent : root.tokens.muted
      strokeWidth: 1.5
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M13.7 13.7 L19 19" }
    }
  }

  Rectangle {
    visible: root.showStatus
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 5
    width: 6
    height: 6
    radius: 3
    color: root.active ? root.accent : root.tokens.muted
  }
}
