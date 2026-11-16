import QtQuick

Item {
  id: root
  required property var tokens

  property string seedName: ""
  clip: true

  readonly property int seed: {
    var value = 0
    for (var i = 0; i < seedName.length; i++)
      value = (value * 31 + seedName.charCodeAt(i)) % 100003
    return value
  }

  readonly property int starCount: {
    if (!root.tokens.stars)
      return 0
    var count = Math.round((width * height) / 16000 * root.tokens.starDensity)
    return Math.max(0, Math.min(220, count))
  }

  // Deterministic positions: reloads and monitor changes keep the sky stable.
  function hash(index, seed) {
    var value = Math.sin(index * 12.9898 + seed * 78.233) * 43758.5453
    return value - Math.floor(value)
  }

  Repeater {
    model: root.starCount

    delegate: Item {
      id: star
      width: 1 + root.hash(index + root.seed, 1) * 1.7
      height: width
      x: root.hash(index + root.seed, 2) * root.width
      y: root.hash(index + root.seed, 3) * root.height

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: index % 11 === 0 ? root.tokens.gold
          : index % 6 === 0 ? root.tokens.lavender
          : root.tokens.text
        opacity: 0.22 + root.hash(index + root.seed, 4) * 0.5

        SequentialAnimation on opacity {
          running: root.tokens.animations
          loops: Animation.Infinite
          PauseAnimation { duration: 600 + root.hash(index + root.seed, 5) * 5000 }
          NumberAnimation {
            to: 0.1
            duration: 700 + root.hash(index + root.seed, 6) * 1300
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            to: 0.82
            duration: 700 + root.hash(index + root.seed, 7) * 1300
            easing.type: Easing.InOutSine
          }
        }
      }
    }
  }

  Repeater {
    model: root.tokens.shootingStars && root.tokens.animations ? root.tokens.meteorCount : 0

    delegate: Item {
      id: meteor
      width: 130 + root.hash(index + root.seed, 20) * 80
      height: 2
      visible: progress > 0.001
      opacity: 0
      rotation: root.tokens.meteorAngle

      property real progress: 0
      readonly property real startY: -root.height * 0.25 + root.hash(index + root.seed, 21) * root.height * 0.85
      readonly property real travel: root.width + width * 2
      readonly property real angleRadians: root.tokens.meteorAngle * Math.PI / 180

      x: -width + progress * travel
      y: startY + progress * travel * Math.tan(angleRadians)

      Row {
        anchors.fill: parent
        spacing: 0

        Rectangle {
          width: parent.width * 0.62
          height: parent.height
          radius: height / 2
          color: Qt.alpha(root.tokens.cyan, 0.1)
        }
        Rectangle {
          width: parent.width * 0.25
          height: parent.height
          radius: height / 2
          color: Qt.alpha(root.tokens.cyan, 0.32)
        }
        Rectangle {
          width: parent.width * 0.13
          height: parent.height
          radius: height / 2
          color: root.tokens.text
        }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 3
        radius: 1.5
        color: root.tokens.text
      }

      SequentialAnimation {
        loops: Animation.Infinite

        PauseAnimation { duration: 1800 + root.hash(index + root.seed, 22) * 9000 }

        ParallelAnimation {
          NumberAnimation {
            target: meteor
            property: "opacity"
            from: 0
            to: 0.9
            duration: 120
          }
          NumberAnimation {
            target: meteor
            property: "progress"
            from: 0
            to: 1
            duration: 850 + root.hash(index + root.seed, 23) * 700
            easing.type: Easing.InOutSine
          }
        }

        NumberAnimation {
          target: meteor
          property: "opacity"
          to: 0
          duration: 220
        }

        PropertyAction {
          target: meteor
          property: "progress"
          value: 0
        }
      }
    }
  }
}
