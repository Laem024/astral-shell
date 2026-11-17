import QtQuick

Rectangle {
  id: root
  required property var tokens

  property string label: ""
  property string armedLabel: ""
  property bool solid: false
  property string tone: "accent"
  // Destructive actions arm on the first click and run on the second.
  property bool confirm: false
  property bool armed: false

  readonly property color accent: root.tone === "alert" ? root.tokens.alert : root.tokens.cyan
  readonly property bool hovered: mouse.containsMouse && root.enabled

  signal clicked()

  implicitWidth: labelText.implicitWidth + (root.solid ? 48 : 40)
  implicitHeight: 40
  radius: root.tokens.controlRadius
  color: root.solid
    ? (mouse.pressed ? Qt.darker(root.accent, 1.1) : root.hovered ? Qt.lighter(root.accent, 1.06) : root.accent)
    : mouse.pressed || root.armed ? Qt.alpha(root.accent, 0.16)
    : root.hovered ? Qt.alpha(root.accent, 0.08)
    : "transparent"
  border.width: root.solid ? 0 : 1
  border.color: root.solid ? "transparent"
    : root.armed || root.hovered ? Qt.alpha(root.accent, 0.7)
    : root.tokens.border
  opacity: root.enabled ? 1 : 0.4

  Behavior on color {
    ColorAnimation { duration: root.tokens.hoverDuration }
  }
  Behavior on border.color {
    ColorAnimation { duration: root.tokens.hoverDuration }
  }

  Text {
    id: labelText
    anchors {
      left: parent.left
      right: parent.right
      leftMargin: 16
      rightMargin: 16
      verticalCenter: parent.verticalCenter
    }
    text: root.armed && root.armedLabel.length > 0 ? root.armedLabel : root.label
    color: root.solid ? root.tokens.background
      : root.tone === "alert" || root.armed || root.hovered ? root.accent
      : root.tokens.text
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    font {
      family: root.tokens.font
      pixelSize: root.solid ? root.tokens.labelSize : root.tokens.bodySize
      weight: root.solid ? Font.DemiBold : Font.Medium
      letterSpacing: 0.3
    }
  }

  Timer {
    id: disarm
    interval: 4000
    onTriggered: root.armed = false
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (!root.enabled)
        return
      if (!root.confirm) {
        root.clicked()
        return
      }
      if (root.armed) {
        disarm.stop()
        root.armed = false
        root.clicked()
      } else {
        root.armed = true
        disarm.restart()
      }
    }
  }
}
