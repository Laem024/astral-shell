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
  readonly property int orbSize: root.compact ? 40 : 48
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
    implicitHeight: 150
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 12

      Item {
        id: orb
        Layout.preferredWidth: root.orbSize
        Layout.preferredHeight: root.orbSize
        Layout.alignment: Qt.AlignHCenter

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
          Shape {
            anchors.centerIn: parent
            width: 24; height: 24
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeColor: root.accent
              strokeWidth: 1.7
              capStyle: ShapePath.RoundCap
              joinStyle: ShapePath.RoundJoin
              fillColor: "transparent"
              PathSvg {
                path: ({
                  lock: "M7 10 V7 A5 5 0 0 1 17 7 V10 M5 10 H19 V21 H5 Z M12 14 V17",
                  logout: "M10 3 H4 V21 H10 M9 12 H21 M17 8 L21 12 L17 16",
                  suspend: "M20 15 A9 9 0 1 1 9 3 A7 7 0 0 0 20 15 Z",
                  reboot: "M20 10 A8 8 0 1 0 20 16 M20 3 V10 H13",
                  poweroff: "M12 2 V11 M7 5 A9 9 0 1 0 17 5"
                })[root.actionData.id] || ""
              }
            }
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
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          color: root.holding ? root.accent : root.tokens.text
          font { family: root.tokens.font; pixelSize: root.compact ? 13 : 14; weight: Font.DemiBold }
        }
        Text {
          Layout.fillWidth: true
          text: root.holding ? "Keep holding…"
            : root.holdRequired && (root.hovered || root.visualFocus) ? "Hold to confirm"
            : root.detail
          textFormat: Text.PlainText
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          color: root.holding ? root.accent : root.tokens.muted
          font { family: root.tokens.font; pixelSize: root.compact ? 10 : 11 }
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignHCenter
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
      : Qt.alpha(root.accent, 0.22)
    Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
    Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
  }
}
