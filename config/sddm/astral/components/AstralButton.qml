import QtQuick

Rectangle {
  id: root
  required property var tokens

  property string label: ""
  property bool solid: false
  property bool flat: false
  signal clicked()

  implicitWidth: labelText.implicitWidth + (root.solid ? 48 : 30)
  implicitHeight: root.solid ? 50 : 38
  radius: root.solid ? 15 : 11
  color: {
    if (root.solid)
      return !root.enabled ? Qt.alpha(root.tokens.cyan, 0.15)
        : mouse.pressed ? Qt.darker(root.tokens.cyan, 1.1)
        : mouse.containsMouse ? Qt.lighter(root.tokens.cyan, 1.06)
        : root.tokens.cyan
    if (root.flat)
      return mouse.containsMouse && root.enabled ? Qt.alpha(root.tokens.cyan, 0.09) : "transparent"
    return mouse.containsMouse && root.enabled ? root.tokens.glassDeep : root.tokens.glassSoft
  }
  border.width: root.solid && root.enabled ? 0 : 1
  border.color: mouse.containsMouse && root.enabled && !root.solid
    ? Qt.alpha(root.tokens.cyan, 0.42) : root.tokens.glassEdge
  opacity: root.enabled ? 1 : 0.85

  Behavior on color {
    ColorAnimation { duration: root.tokens.hoverDuration }
  }
  Behavior on border.color {
    ColorAnimation { duration: root.tokens.hoverDuration }
  }

  Rectangle {
    visible: root.solid && root.enabled
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      leftMargin: 14
      rightMargin: 14
    }
    height: 1
    color: Qt.alpha("#FFFFFF", 0.35)
  }

  Text {
    id: labelText
    anchors {
      left: parent.left
      right: parent.right
      leftMargin: root.solid ? 20 : 14
      rightMargin: root.solid ? 20 : 14
      verticalCenter: parent.verticalCenter
    }
    text: root.label
    color: root.solid ? (root.enabled ? root.tokens.background : root.tokens.muted) : root.tokens.text
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    font {
      family: root.tokens.font
      pixelSize: 13
      weight: root.solid ? Font.DemiBold : Font.Medium
      letterSpacing: 0.4
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (root.enabled) root.clicked()
  }
}
