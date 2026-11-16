import QtQuick
import QtQuick.Shapes

InfoTile {
  id: root
  objectName: "emblem"
  required property string logoGlyph
  required property string logoImage
  compact: true
  glyph: image.status === Image.Ready || image.status === Image.Error ? "" : logoGlyph
  detail: "Arch · Astral"
  accent: tokens.cyan
  glyphSize: 25
  implicitWidth: 40
  implicitHeight: 40
  Rectangle {
    anchors.centerIn: parent
    width: 38; height: 38
    radius: 7
    color: Qt.alpha(root.tokens.cyan, 0.06)
    border.color: Qt.alpha(root.ink, 0.25)
    Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
  }
  NeonOutline {
    anchors.centerIn: parent
    width: 38; height: 38; radius: 7
    tokens: root.tokens
    active: root.hovered
  }
  Shape {
    anchors.centerIn: parent
    width: 26; height: 28
    visible: image.status !== Image.Ready && (root.logoGlyph === "" || image.status === Image.Error)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: "transparent"
      fillColor: root.ink
      PathSvg { path: "M13 0 L9 9 L13 11 L8 10 L0 28 L8 24 C8 16 18 16 18 24 L26 28 L18 11 L16 13 L17 9 Z" }
    }
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
