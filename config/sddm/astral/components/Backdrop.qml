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
      NumberAnimation { duration: root.animated ? 900 : 0 }
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

  // Soft aurora veils slide over the artwork and give the glass something
  // to refract. They stay very low contrast so the panel text keeps winning.
  Rectangle {
    id: veilTop
    width: root.width * 1.3
    height: root.height * 0.62
    y: -height * 0.32
    rotation: -9
    opacity: root.animated ? 0.75 : 0.55
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 0.42; color: Qt.alpha(root.tokens.cyan, 0.11) }
      GradientStop { position: 0.62; color: Qt.alpha(root.tokens.lavender, 0.05) }
      GradientStop { position: 1.0; color: "transparent" }
    }

    SequentialAnimation on x {
      running: root.animated && root.tokens.backgroundDrift
      loops: Animation.Infinite
      NumberAnimation {
        from: -root.width * 0.18
        to: root.width * 0.02
        duration: 46000
        easing.type: Easing.InOutSine
      }
      NumberAnimation {
        from: root.width * 0.02
        to: -root.width * 0.18
        duration: 46000
        easing.type: Easing.InOutSine
      }
    }
  }

  Rectangle {
    id: veilBottom
    width: root.width * 1.15
    height: root.height * 0.5
    y: root.height * 0.62
    rotation: 7
    opacity: root.animated ? 0.6 : 0.4
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 0.5; color: Qt.alpha(root.tokens.gold, 0.07) }
      GradientStop { position: 1.0; color: "transparent" }
    }

    SequentialAnimation on x {
      running: root.animated && root.tokens.backgroundDrift
      loops: Animation.Infinite
      NumberAnimation {
        from: -root.width * 0.04
        to: root.width * 0.1
        duration: 58000
        easing.type: Easing.InOutSine
      }
      NumberAnimation {
        from: root.width * 0.1
        to: -root.width * 0.04
        duration: 58000
        easing.type: Easing.InOutSine
      }
    }
  }

  // Vignette: darker edges, transparent center, so the composition reads as a
  // lit stage around the glass panel.
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
      GradientStop { position: 0.3; color: "transparent" }
      GradientStop { position: 0.72; color: "transparent" }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.4) }
    }
  }

  Image {
    anchors.fill: parent
    source: Qt.resolvedUrl("../assets/texture/grain.png")
    fillMode: Image.Tile
    opacity: 0.07
    smooth: false
  }

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
      GradientStop { position: 0.26; color: "transparent" }
      GradientStop { position: 0.74; color: "transparent" }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.tokens.background
    opacity: root.tokens.overlay
  }

  // Faint orbital lines centred behind the login panel.
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
        border.color: Qt.alpha(root.tokens.cyan, 0.02 + modelData * 0.018)
      }
    }
  }
}
