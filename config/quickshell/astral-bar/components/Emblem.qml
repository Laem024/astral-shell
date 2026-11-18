import QtQuick

InfoTile {
  id: root
  objectName: "emblem"
  required property string logoGlyph
  required property string logoImage
  compact: true
  glyph: ""
  detail: "Open Astral launcher"
  accent: tokens.cyan
  glyphSize: 25
  implicitWidth: 40
  implicitHeight: 40
  BarTile {
    anchors.centerIn: parent
    width: 36; height: 36
    tokens: root.tokens
    hovered: root.hovered
    focused: root.activeFocus
    tinted: true
    scale: root.hovered ? 1.04 : 1
    Behavior on scale { NumberAnimation { duration: root.tokens.hoverDuration } }
  }
  Image {
    objectName: "launcherStar"
    anchors.centerIn: parent
    width: 24; height: 24
    sourceSize: Qt.size(96, 96)
    smooth: true
    mipmap: true
    antialiasing: true
    // Qt's SVG rasterizer provides edge coverage before texture filtering.
    // A single shaded silhouette avoids subpixel outlines at this size.
    source: "data:image/svg+xml;charset=utf-8," + encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      + '<defs><linearGradient id="light" x1="0" y1="0" x2="1" y2="1">'
      + '<stop stop-color="' + Qt.lighter(root.ink, 1.3) + '"/>'
      + '<stop offset="0.5" stop-color="' + root.ink + '"/>'
      + '<stop offset="1" stop-color="' + Qt.darker(root.ink, 1.3) + '"/>'
      + '</linearGradient></defs>'
      + '<path fill="url(#light)" d="M12 2 L14.8 9.2 L22 12 L14.8 14.8 L12 22 L9.2 14.8 L2 12 L9.2 9.2 Z"/>'
      + '</svg>')
    rotation: root.hovered ? 90 : 0
    Behavior on rotation {
      NumberAnimation { duration: root.tokens.workspaceDuration; easing.type: Easing.InOutCubic }
    }
    visible: image.status !== Image.Ready && (root.logoGlyph === "" || image.status === Image.Error)
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
    onStatusChanged: if (status === Image.Error) console.warn("Astral: logo unavailable; using Astral emblem")
  }
}
