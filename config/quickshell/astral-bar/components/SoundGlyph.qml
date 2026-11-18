pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Line sigils for the sound page, drawn on the same 24×24 canvas and 1.5 px
// stroke as CaptureGlyph and the bar instruments.
Item {
  id: root
  required property color ink
  // speaker · headphones · microphone · display · mixer · stream
  property string kind: "speaker"
  property bool muted: false
  property real level: 1
  readonly property real gain: Math.max(0, Math.min(1, root.level))
  implicitWidth: 24
  implicitHeight: 24
  Accessible.ignored: true

  Shape {
    anchors.fill: parent
    visible: root.kind === "speaker"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.5
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap
      fillColor: Qt.alpha(root.ink, 0.16)
      PathSvg { path: "M4 9.5 H7.5 L12.5 5 V19 L7.5 14.5 H4 Z" }
    }
    // The arcs grow with the current level, and disappear when silenced.
    ShapePath {
      strokeColor: root.muted || root.gain <= 0.02 ? "transparent" : root.ink
      strokeWidth: 1.5
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M15.5 9.5 A3.6 3.6 0 0 1 15.5 14.5" }
    }
    ShapePath {
      strokeColor: root.muted ? "transparent" : Qt.alpha(root.ink, root.gain >= 0.55 ? 1 : 0.22)
      strokeWidth: 1.5
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M18.5 6.75 A7.5 7.5 0 0 1 18.5 17.25" }
    }
  }

  // Speaker mute keeps the body and replaces the arcs with a cross.
  Shape {
    anchors.fill: parent
    visible: root.kind === "speaker" && root.muted
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.6
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M15.5 9.5 L20.5 14.5 M20.5 9.5 L15.5 14.5" }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.kind === "microphone"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.5
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap
      fillColor: Qt.alpha(root.ink, 0.16)
      PathSvg { path: "M9 6 C9 2 15 2 15 6 V11 C15 15 9 15 9 11 Z" }
    }
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.5
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M6 10.5 V11.5 C6 19 18 19 18 11.5 V10.5 M12 17.2 V21 M9 21 H15" }
    }
  }

  Shape {
    anchors.fill: parent
    visible: root.kind === "headphones"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.5
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M4.5 15 V12 A7.5 7.5 0 0 1 19.5 12 V15" }
    }
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.5
      joinStyle: ShapePath.RoundJoin
      fillColor: Qt.alpha(root.ink, 0.16)
      PathSvg { path: "M4.75 13 H6.75 A1.75 1.75 0 0 1 8.5 14.75 V17.75 A1.75 1.75 0 0 1 6.75 19.5 H4.75 A1.75 1.75 0 0 1 3 17.75 V14.75 A1.75 1.75 0 0 1 4.75 13 Z" }
    }
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.5
      joinStyle: ShapePath.RoundJoin
      fillColor: Qt.alpha(root.ink, 0.16)
      PathSvg { path: "M19.25 13 H17.25 A1.75 1.75 0 0 0 15.5 14.75 V17.75 A1.75 1.75 0 0 0 17.25 19.5 H19.25 A1.75 1.75 0 0 0 21 17.75 V14.75 A1.75 1.75 0 0 0 19.25 13 Z" }
    }
  }

  // Muted microphones and headsets get a single diagonal cut.
  Shape {
    anchors.fill: parent
    visible: root.kind !== "speaker" && root.muted
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.6
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M4.5 4.5 L19.5 19.5" }
    }
  }

  // Three faders: or the mixer section and its empty state.
  Shape {
    anchors.fill: parent
    visible: root.kind === "mixer"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: Qt.alpha(root.ink, 0.38)
      strokeWidth: 1.4
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M6 4.5 V19.5 M12 4.5 V19.5 M18 4.5 V19.5" }
    }
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 3.2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M3.75 8.5 H8.25 M9.75 14 H14.25 M15.75 6.5 H20.25" }
    }
  }

  // A small equalizer reads as a live playback stream.
  Shape {
    anchors.fill: parent
    visible: root.kind === "stream"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 2.4
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M5 10.5 V13.5 M9 6 V18 M13 8 V16 M17 7 V17 M21 10 V14" }
    }
  }

  // HDMI and DisplayPort sinks show the display they play through.
  Shape {
    anchors.fill: parent
    visible: root.kind === "display"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.5
      joinStyle: ShapePath.RoundJoin
      fillColor: Qt.alpha(root.ink, 0.14)
      PathSvg { path: "M4 4.5 H20 Q20.5 4.5 20.5 5 V15.5 Q20.5 16 20 16 H4 Q3.5 16 3.5 15.5 V5 Q3.5 4.5 4 4.5 Z" }
    }
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.5
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M12 16 V20.5 M8.5 20.5 H15.5" }
    }
  }
}
