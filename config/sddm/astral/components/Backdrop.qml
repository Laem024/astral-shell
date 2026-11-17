import QtQuick

Rectangle {
  id: root
  required property var tokens

  color: root.tokens.background
  clip: true

  readonly property bool animated: root.tokens.animations

  Image {
    id: background
    anchors.fill: parent
    source: root.tokens.backgroundSource
    fillMode: root.tokens.backgroundFill
    asynchronous: true
    cache: true
    smooth: true
    opacity: status === Image.Ready ? 1 : 0
    scale: root.tokens.backgroundDrift && root.animated ? drift : 1.0
    property real drift: 1.03

    Behavior on opacity {
      NumberAnimation { duration: root.animated ? 600 : 0 }
    }
    NumberAnimation on drift {
      running: root.tokens.backgroundDrift && root.animated
      from: 1.03
      to: 1.08
      duration: 80000
      loops: Animation.Infinite
      easing.type: Easing.InOutSine
    }
  }

  // Tints the artwork toward the active palette so both modes stay legible.
  Rectangle {
    anchors.fill: parent
    color: root.tokens.background
    opacity: root.tokens.overlay
  }

  // Edge fade keeps the corners quiet and the card centred.
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.alpha(root.tokens.background, 0.45) }
      GradientStop { position: 0.3; color: "transparent" }
      GradientStop { position: 0.7; color: "transparent" }
      GradientStop { position: 1.0; color: Qt.alpha(root.tokens.background, 0.6) }
    }
  }

  Image {
    anchors.fill: parent
    source: Qt.resolvedUrl("../assets/texture/grain.png")
    fillMode: Image.Tile
    opacity: 0.05
    smooth: false
  }

  // Faint orbital rings centred behind the card.
  Item {
    anchors.centerIn: parent
    width: Math.max(root.width, root.height) * 1.05
    height: width

    Repeater {
      model: [0.94, 0.72, 0.5]

      delegate: Rectangle {
        anchors.centerIn: parent
        width: parent.width * modelData
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(root.tokens.cyan, 0.04)
      }
    }
  }
}
