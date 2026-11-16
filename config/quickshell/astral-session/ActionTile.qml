pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

Button {
  id: root
  required property var tokens
  required property var actionData
  property bool compact: false
  property bool holding: false
  property real progress: 0
  readonly property bool holdRequired: actionData.hold === true
  readonly property color accent: actionData.accent === "alert" ? tokens.alert : actionData.accent === "gold" ? tokens.gold : tokens.cyan
  readonly property string detail: actionData.detail || ""
  readonly property int orbSize: root.compact ? 36 : 42
  signal holdStarted()
  signal holdEnded()
  signal activated()

  padding: 0
  focusPolicy: Qt.StrongFocus
  Accessible.name: actionData.label
  Accessible.description: holdRequired ? "Hold to " + actionData.label.toLowerCase() : actionData.label
  onPressed: if (root.holdRequired) root.holdStarted()
  onReleased: if (root.holdRequired) root.holdEnded()
  onCanceled: if (root.holdRequired) root.holdEnded()
  onClicked: if (!root.holdRequired) root.activated()

  contentItem: Item {
    implicitHeight: root.compact ? 54 : 62
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: root.compact ? 10 : 12
      anchors.rightMargin: root.compact ? 10 : 12
      spacing: root.compact ? 10 : 14

      Item {
        id: orb
        Layout.preferredWidth: root.orbSize
        Layout.preferredHeight: root.orbSize
        Layout.alignment: Qt.AlignVCenter

        // The hold progress is a ring around the symbol, not a bar.
        Shape {
          id: ring
          visible: root.holdRequired
          anchors.centerIn: parent
          width: orb.width + 8
          height: orb.height + 8
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(root.accent, 0.2)
            strokeWidth: 1
            PathAngleArc {
              centerX: ring.width / 2
              centerY: ring.height / 2
              radiusX: ring.width / 2 - 0.5
              radiusY: ring.height / 2 - 0.5
              startAngle: -90
              sweepAngle: 359.9
            }
          }
          ShapePath {
            fillColor: "transparent"
            strokeColor: root.progress > 0.001 ? root.accent : "transparent"
            strokeWidth: 2.2
            capStyle: ShapePath.RoundCap
            PathAngleArc {
              centerX: ring.width / 2
              centerY: ring.height / 2
              radiusX: ring.width / 2 - 0.5
              radiusY: ring.height / 2 - 0.5
              startAngle: -90
              sweepAngle: 359.9 * root.progress
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: Qt.alpha(root.accent, root.holding ? 0.2 : root.hovered ? 0.1 : 0.06)
          border.color: Qt.alpha(root.accent, root.holding ? 0.6 : 0.18)
          Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
          Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
          Text {
            anchors.centerIn: parent
            text: root.actionData.glyph
            color: root.accent
            font { family: root.tokens.mono; pixelSize: root.compact ? 18 : 21 }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 1
        Text {
          Layout.fillWidth: true
          text: root.actionData.label
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: root.holding ? root.accent : root.tokens.text
          font { family: root.tokens.font; pixelSize: root.compact ? 13 : 15; weight: Font.DemiBold }
        }
        Text {
          Layout.fillWidth: true
          text: root.holding ? "Keep holding…"
            : root.holdRequired && (root.hovered || root.visualFocus) ? "Press and hold to confirm"
            : root.detail
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: root.holding ? root.accent : root.tokens.muted
          font { family: root.tokens.font; pixelSize: root.compact ? 10 : 11 }
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 24
        implicitHeight: 24
        radius: 7
        color: Qt.alpha(root.accent, root.holding ? 0.22 : 0.08)
        border.color: Qt.alpha(root.accent, root.holding ? 0.55 : 0.22)
        Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
        Text {
          anchors.centerIn: parent
          text: root.actionData.shortcut
          color: root.accent
          font { family: root.tokens.mono; pixelSize: 10; weight: Font.DemiBold }
        }
      }
    }
  }

  background: Rectangle {
    radius: root.compact ? 12 : 14
    color: root.holding ? Qt.alpha(root.accent, 0.1)
      : root.down ? Qt.alpha(root.accent, 0.08)
      : root.hovered ? Qt.alpha(root.accent, 0.045)
      : Qt.alpha(root.tokens.muted, 0.025)
    border.width: root.visualFocus ? 1.5 : 1
    border.color: root.visualFocus ? Qt.alpha(root.accent, 0.6)
      : root.holding ? Qt.alpha(root.accent, 0.4)
      : "transparent"
    Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
    Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
  }
}
