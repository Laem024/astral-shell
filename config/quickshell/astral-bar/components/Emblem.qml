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
  BarGlyph {
    anchors.centerIn: parent
    width: 26; height: 26
    kind: "astral"
    ink: root.ink
    visible: image.status !== Image.Ready && (root.logoGlyph === "" || image.status === Image.Error)
    rotation: root.hovered ? 90 : 0
    Behavior on rotation { NumberAnimation { duration: root.tokens.workspaceDuration; easing.type: Easing.InOutCubic } }
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
