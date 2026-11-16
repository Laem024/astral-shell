import QtQuick

Text {
  id: root
  required property var tokens

  signal clicked()

  color: mouse.containsMouse && root.enabled ? root.tokens.cyan : root.tokens.muted
  opacity: root.enabled ? 1 : 0.4
  font {
    family: root.tokens.mono
    pixelSize: 10
    letterSpacing: 0.7
  }

  Behavior on color {
    ColorAnimation { duration: root.tokens.hoverDuration }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (root.enabled) root.clicked()
  }
}
