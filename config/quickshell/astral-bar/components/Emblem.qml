import QtQuick
import QtQuick.Shapes

InfoTile {
  id: root
  objectName: "emblem"
  required property string logoGlyph
  required property string logoImage
  compact: true
  glyph: ""
  detail: "Open Astral controls"
  accent: tokens.cyan
  glyphSize: 25
  implicitWidth: 40
  implicitHeight: 40
  Rectangle {
    anchors.centerIn: parent
    width: 36; height: 36
    radius: 11
    color: Qt.alpha(root.tokens.cyan, root.hovered ? 0.18 : 0.08)
    border.color: root.activeFocus ? root.tokens.gold : Qt.alpha(root.tokens.cyan, root.hovered ? 0.55 : 0.2)
    scale: root.hovered ? 1.04 : 1
    Behavior on scale { NumberAnimation { duration: root.tokens.hoverDuration } }
    Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
    Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
  }
  Shape {
    anchors.centerIn: parent
    width: 24; height: 24
    visible: image.status !== Image.Ready && (root.logoGlyph === "" || image.status === Image.Error)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: "transparent"
      fillColor: root.ink
      PathSvg { path: "M12 1 L7.6 10.2 L11 12 L7 11.5 L2 23 L8.5 19.2 C8.5 13.8 15.5 13.8 15.5 19.2 L22 23 L16.6 11.3 L14.5 12.6 L16 10 Z" }
    }
  }
  Text {
    anchors.centerIn: parent
    visible: image.status !== Image.Ready && image.status !== Image.Error && root.logoGlyph !== ""
    text: root.logoGlyph
    color: root.ink
    font { family: root.tokens.mono; pixelSize: 24 }
  }
  Image {
    id: image
    anchors.centerIn: parent
    width: 29; height: 29
    source: root.logoImage ? (root.logoImage.startsWith("file:") ? root.logoImage : "file://" + root.logoImage) : ""
    fillMode: Image.PreserveAspectFit
    visible: status === Image.Ready
    onStatusChanged: if (status === Image.Error) console.warn("Astral: logo unavailable; using Arch emblem")
  }
}
