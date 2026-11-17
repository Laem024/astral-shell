import QtQuick

Item {
  id: root
  required property var tokens

  property string source: ""
  property string initials: "?"
  property int size: 64

  width: root.size
  height: root.size
  clip: true

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: root.tokens.sunken
  }

  Image {
    id: picture
    anchors.fill: parent
    source: root.source
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    visible: status === Image.Ready
  }

  Text {
    anchors.centerIn: parent
    visible: !picture.visible
    text: root.initials
    color: root.tokens.cyan
    font {
      family: root.tokens.font
      pixelSize: Math.round(root.size * 0.34)
      weight: Font.Medium
    }
  }

  // Square image corners are masked by a ring in the surface colour, so the
  // picture reads as a circle without extra graphics modules.
  Rectangle {
    anchors.centerIn: parent
    width: root.size * 1.6
    height: width
    radius: width / 2
    color: "transparent"
    border.width: root.size * 0.3
    border.color: root.tokens.surface
  }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: Qt.alpha(root.tokens.cyan, 0.4)
  }
}
