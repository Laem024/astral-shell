pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../../common" as Design

Item {
  id: root
  required property Design.Theme tokens
  required property string kind
  objectName: kind
  readonly property bool hovered: hover.hovered
  property bool vertical: false
  property bool compact: false
  property string label: ""
  property string detail: label
  property real level: 1
  property color accent: tokens.cyan
  property bool warningEnabled: true
  property bool externalPower: false
  readonly property bool warning: warningEnabled && kind === "battery" && level >= 0 && level < 0.2
  property color ink: warning ? tokens.alert : hover.hovered ? tokens.lavender : accent
  Behavior on ink { ColorAnimation { duration: root.tokens.hoverDuration } }
  signal activated()
  signal summaryActivated()
  implicitWidth: vertical ? 48 : (compact ? 34 : 84)
  implicitHeight: vertical ? (compact ? 38 : 54) : 40
  Accessible.name: detail
  Accessible.role: Accessible.Button

  // One 24 px line instrument per status, drawn with the same 1.5 px stroke as
  // the sound and capture sigils. Signal and charge are shown by stroke weight.
  Item {
    id: instrument
    width: 24; height: 24
    x: root.vertical || root.compact ? (root.width - width) / 2 : 10
    y: root.vertical ? 6 : (root.height - height) / 2
    function strength(index: int): real { return root.level >= (index + 1) / 3 - 0.2 ? 1 : 0.2; }

    Shape {
      visible: root.kind === "network"
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.alpha(root.ink, instrument.strength(0))
        strokeWidth: 1.7
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 12; centerY: 18; radiusX: 4; radiusY: 4; startAngle: -135; sweepAngle: 90 }
      }
      ShapePath {
        strokeColor: Qt.alpha(root.ink, instrument.strength(1))
        strokeWidth: 1.7
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 12; centerY: 18; radiusX: 8; radiusY: 8; startAngle: -135; sweepAngle: 90 }
      }
      ShapePath {
        strokeColor: Qt.alpha(root.ink, instrument.strength(2))
        strokeWidth: 1.7
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 12; centerY: 18; radiusX: 12; radiusY: 12; startAngle: -135; sweepAngle: 90 }
      }
    }
    Rectangle {
      visible: root.kind === "network"
      x: 10.5; y: 16.5
      width: 3; height: 3; radius: 1.5
      color: root.ink
    }

    SoundGlyph {
      visible: root.kind === "audio"
      anchors.fill: parent
      kind: "speaker"
      muted: root.level <= 0
      level: root.level
      ink: root.ink
    }

    Item {
      visible: root.kind === "battery"
      anchors.fill: parent
      Rectangle {
        x: 1; y: 6
        width: 20; height: 12; radius: 3.5
        color: "transparent"
        border.color: root.ink
        border.width: 1.5
      }
      Rectangle {
        x: 22; y: 9.5
        width: 2; height: 5; radius: 1
        color: root.ink
      }
      Rectangle {
        x: 4; y: 9
        width: 14 * Math.max(0, Math.min(1, root.level)); height: 6; radius: 1.5
        color: root.ink
        opacity: root.externalPower ? 0.25 : 1
      }
      Shape {
        visible: root.externalPower
        x: 8; y: 7
        width: 7; height: 10
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: "transparent"
          fillColor: root.ink
          startX: 4.5; startY: 0
          PathLine { x: 0; y: 5.5 }
          PathLine { x: 3; y: 5.5 }
          PathLine { x: 2; y: 10 }
          PathLine { x: 7; y: 4 }
          PathLine { x: 4; y: 4 }
          PathLine { x: 4.5; y: 0 }
        }
      }
    }

    Item {
      visible: root.kind === "notifications"
      anchors.fill: parent
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: root.ink
          strokeWidth: 1.5
          joinStyle: ShapePath.RoundJoin
          capStyle: ShapePath.RoundCap
          fillColor: Qt.alpha(root.ink, 0.14)
          PathSvg { path: "M12 3.5 C8.4 3.5 6.5 6.2 6.5 9.8 V13.5 L4.5 16.5 H19.5 L17.5 13.5 V9.8 C17.5 6.2 15.6 3.5 12 3.5 Z" }
        }
        ShapePath {
          strokeColor: root.ink
          strokeWidth: 1.5
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathSvg { path: "M10 19.5 Q12 21.5 14 19.5" }
        }
      }
      Rectangle {
        visible: root.level > 0
        x: 15.5; y: 0
        width: 8; height: 8; radius: 4
        color: root.tokens.alert
        border.width: 1.5
        border.color: root.tokens.surface
      }
    }
  }
  Text {
    visible: !root.vertical && !root.compact
    x: 42; y: 8
    width: root.width - x - 6
    text: ({network: "NET", audio: "VOL", battery: "PWR", notifications: "LOG"})[root.kind] || "SYS"
    elide: Text.ElideRight
    color: root.tokens.muted
    font.family: root.tokens.mono
    font.pixelSize: 9
    font.letterSpacing: 1.2
  }
  Text {
    id: valueLabel
    visible: !root.compact
    x: root.vertical ? 0 : 42
    y: root.vertical ? 32 : 20
    width: root.vertical ? root.width : root.width - x - 6
    horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
    text: root.label
    color: root.warning ? root.tokens.alert : root.tokens.text
    font.family: root.tokens.mono
    font.pixelSize: root.vertical ? 11 : root.tokens.textSize
    font.weight: Font.Medium
    elide: Text.ElideRight
  }
  HoverHandler { id: hover }
  TapHandler {
    onTapped: event => {
      if (root.kind === "notifications" && valueLabel.visible && event.position.x >= valueLabel.x && event.position.y >= valueLabel.y) root.summaryActivated();
      else root.activated();
    }
  }
}
