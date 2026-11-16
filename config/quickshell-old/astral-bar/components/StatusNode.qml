pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../design" as Design

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
  implicitWidth: vertical ? 48 : (compact ? 34 : 68)
  implicitHeight: vertical ? (compact ? 38 : 54) : 40
  Accessible.name: detail
  Accessible.role: Accessible.Button
  Item {
    id: instrument
    width: 26; height: 24
    x: root.vertical || root.compact ? (root.width - width) / 2 : 2
    y: root.vertical ? 3 : (root.height - height) / 2
    // Small solid instruments replace the family of circular sigils.
    Row {
      visible: root.kind === "network" || root.kind === "audio"
      anchors.centerIn: parent
      spacing: 2
      Repeater {
        model: 5
        Rectangle {
          required property int index
          width: 3
          height: root.kind === "network" ? 4 + index * 3 : [6, 14, 20, 10, 4][index]
          anchors.bottom: parent.bottom
          radius: 1
          color: root.ink
          opacity: index / 5 < root.level ? 1 : 0.18
        }
      }
      height: 20
    }
    Rectangle {
      visible: root.kind === "battery"
      anchors.centerIn: parent
      width: 23; height: 12; radius: 3
      color: "transparent"
      border.color: root.ink
      border.width: 1
      Rectangle { x: 24; y: 4; width: 2; height: 4; radius: 1; color: root.ink }
      Rectangle {
        x: 3; y: 3
        width: 17 * Math.max(0, Math.min(1, root.level)); height: 6; radius: 1
        color: root.ink
        opacity: root.externalPower ? 0.25 : 1
      }
      // Keep the bolt inside the outline, with a dim charge meter behind it.
      Shape {
        visible: root.externalPower
        anchors.centerIn: parent
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
    Rectangle {
      visible: root.kind === "notifications"
      anchors.centerIn: parent
      width: 21; height: 20; radius: 4
      color: "transparent"; border.color: root.ink
      Rectangle { x: 5; y: 6; width: 11; height: 1; color: root.ink }
      Rectangle { x: 5; y: 10; width: 7; height: 1; color: root.ink }
      Rectangle { visible: root.level > 0; x: 17; y: -2; width: 5; height: 5; radius: 2.5; color: root.tokens.alert }
    }
  }
  Text {
    id: valueLabel
    visible: !root.compact
    x: root.vertical ? 0 : 33
    y: root.vertical ? 32 : 20
    width: root.vertical ? root.width : root.width - x - 3
    horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
    text: root.label
    color: root.warning ? root.tokens.alert : root.tokens.text
    font.family: root.tokens.mono
    font.pixelSize: 11
    elide: Text.ElideRight
  }
  Text {
    visible: !root.vertical && !root.compact
    x: 33; y: 6
    text: ({network: "NET", audio: "VOL", battery: "PWR", notifications: "LOG"})[root.kind] || "SYS"
    color: root.tokens.muted
    font.family: root.tokens.mono
    font.pixelSize: 8
    font.letterSpacing: 0.5
  }
  HoverHandler { id: hover }
  TapHandler {
    onTapped: event => {
      if (root.kind === "notifications" && valueLabel.visible && event.position.x >= valueLabel.x && event.position.y >= valueLabel.y) root.summaryActivated();
      else root.activated();
    }
  }
}
