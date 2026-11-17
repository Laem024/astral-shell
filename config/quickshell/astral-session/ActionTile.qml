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
  readonly property bool destructive: actionData.id === "reboot" || actionData.id === "poweroff"
  readonly property color accent: destructive || actionData.accent === "alert" ? tokens.alert
    : actionData.accent === "gold" ? tokens.gold : tokens.cyan
  readonly property string detail: actionData.detail || ""
  readonly property int orbSize: root.compact ? 36 : 40
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
    implicitHeight: root.compact ? 52 : 60
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: root.compact ? 12 : 16
      anchors.rightMargin: root.compact ? 12 : 16
      spacing: root.compact ? 12 : 16

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
          color: Qt.alpha(root.accent, root.holding ? 0.22 : root.hovered ? 0.14 : 0.08)
          border.width: 1
          border.color: Qt.alpha(root.accent, root.holding ? 0.6 : root.hovered ? 0.35 : 0.22)
          Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
          Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
          Text {
            anchors.centerIn: parent
            text: root.actionData.glyph
            color: root.accent
            font { family: root.tokens.mono; pixelSize: root.compact ? 17 : 19 }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        Text {
          Layout.fillWidth: true
          text: root.actionData.label
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: root.holding ? root.accent : root.tokens.text
          font { family: root.tokens.font; pixelSize: root.compact ? 13 : 14; weight: Font.DemiBold }
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
        implicitWidth: 26
        implicitHeight: 22
        radius: root.tokens.rowRadius
        color: root.holding ? Qt.alpha(root.accent, 0.16) : "transparent"
        border.width: 1
        border.color: root.holding ? Qt.alpha(root.accent, 0.55) : root.tokens.border
        Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
        Text {
          anchors.centerIn: parent
          text: root.actionData.shortcut
          color: root.holding ? root.accent : root.tokens.muted
          font { family: root.tokens.mono; pixelSize: 10; weight: Font.DemiBold }
        }
      }
    }
  }

  background: Rectangle {
    radius: root.compact ? root.tokens.rowRadius : root.tokens.cardRadius
    color: root.holding ? Qt.alpha(root.accent, 0.12)
      : root.down ? Qt.alpha(root.accent, 0.1)
      : root.hovered ? Qt.alpha(root.accent, 0.07)
      : root.destructive ? Qt.alpha(root.accent, 0.04)
      : root.tokens.raised
    border.width: root.visualFocus ? 2 : 1
    border.color: root.visualFocus ? Qt.alpha(root.accent, 0.7)
      : root.holding ? Qt.alpha(root.accent, 0.45)
      : root.hovered ? Qt.alpha(root.accent, 0.25)
      : root.tokens.border
    Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
    Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
  }
}
