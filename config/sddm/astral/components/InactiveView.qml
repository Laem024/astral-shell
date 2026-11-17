import QtQuick

Item {
  id: root
  required property var tokens

  property date dateTime: new Date()
  property string hostname: ""
  property bool clickable: true
  property real factor: 1

  signal activate()

  Item {
    anchors.centerIn: parent
    width: 420
    height: column.height
    scale: root.factor

    Column {
      id: column
      width: parent.width
      spacing: 24

      Text {
        width: parent.width
        text: "✦  ASTRAL"
        color: root.tokens.cyan
        horizontalAlignment: Text.AlignHCenter
        font {
          family: root.tokens.mono
          pixelSize: root.tokens.captionSize + 1
          letterSpacing: 3
        }
      }

      ClockBlock {
        width: parent.width
        tokens: root.tokens
        dateTime: root.dateTime
        compact: true
      }

      Text {
        width: parent.width
        visible: root.tokens.showHostname && root.hostname.length > 0
        text: root.hostname
        color: root.tokens.muted
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font {
          family: root.tokens.mono
          pixelSize: root.tokens.captionSize + 1
          letterSpacing: 1
        }
      }

      Item {
        width: parent.width
        height: hint.height

        Rectangle {
          id: hint
          anchors.horizontalCenter: parent.horizontalCenter
          width: hintText.implicitWidth + 56
          height: 40
          radius: root.tokens.controlRadius
          color: root.tokens.surface
          border.width: 1
          border.color: root.tokens.border

          Rectangle {
            id: dot
            anchors {
              left: parent.left
              leftMargin: 20
              verticalCenter: parent.verticalCenter
            }
            width: 6
            height: 6
            radius: 3
            color: root.tokens.cyan

            SequentialAnimation on opacity {
              running: root.tokens.animations
              loops: Animation.Infinite
              NumberAnimation { to: 0.25; duration: 1400; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
            }
          }

          Text {
            id: hintText
            anchors {
              left: dot.right
              leftMargin: 12
              verticalCenter: parent.verticalCenter
            }
            text: root.clickable ? "Click to sign in here" : "Sign in on the primary display"
            color: root.tokens.text
            font {
              family: root.tokens.font
              pixelSize: root.tokens.bodySize
            }
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.clickable
    cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.activate()
  }
}
