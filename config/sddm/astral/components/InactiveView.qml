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
      spacing: 22

      Text {
        width: parent.width
        text: "✦   A S T R A L"
        color: root.tokens.cyan
        horizontalAlignment: Text.AlignHCenter
        font {
          family: root.tokens.mono
          pixelSize: 11
          letterSpacing: 2.4
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
        font {
          family: root.tokens.mono
          pixelSize: 10
          letterSpacing: 1
        }
      }

      Item {
        width: parent.width
        height: hint.height

        Rectangle {
          id: hint
          anchors.horizontalCenter: parent.horizontalCenter
          width: hintText.implicitWidth + 62
          height: 52
          radius: 26
          color: root.tokens.glassSoft
          border.width: 1
          border.color: root.tokens.glassEdge

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
              leftMargin: 14
              right: parent.right
              rightMargin: 24
              verticalCenter: parent.verticalCenter
            }
            text: root.clickable ? "Click to sign in here" : "Sign in on the primary display"
            color: root.tokens.text
            font {
              family: root.tokens.font
              pixelSize: 12
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
