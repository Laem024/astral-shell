import QtQuick
import "../design" as Design

// Input-transparent rings; their size never participates in layout.
Item {
  id: root
  objectName: "neonOutline"
  required property Design.Theme tokens
  property bool active: false
  property color accent: tokens.cyan
  property real radius: 5
  readonly property color ink: tokens.settings.value.mode === "light" ? Qt.darker(accent, 1.35) : accent
  opacity: 0
  function sync(): void {
    fade.stop();
    if (tokens.settings.value.animations) {
      fade.to = active ? 1 : 0;
      fade.start();
    } else opacity = active ? 1 : 0;
  }
  onActiveChanged: sync()
  Component.onCompleted: opacity = active ? 1 : 0
  Connections {
    target: root.tokens
    function onHoverDurationChanged(): void { root.sync(); }
  }
  NumberAnimation { id: fade; target: root; property: "opacity"; duration: 140 }
  Rectangle {
    anchors.fill: parent; anchors.margins: -2
    radius: root.radius + 2
    color: "transparent"; border.width: 2; border.color: root.ink; opacity: 0.08
  }
  Rectangle {
    anchors.fill: parent; anchors.margins: -1
    radius: root.radius + 1
    color: "transparent"; border.width: 2; border.color: root.ink; opacity: 0.22
  }
  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: "transparent"; border.width: 1; border.color: root.ink
  }
}
