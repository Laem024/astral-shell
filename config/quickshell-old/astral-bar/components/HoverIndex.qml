pragma ComponentBehavior: Bound
import QtQuick
import "../design" as Design

// Full-surface, input-transparent drawing. Animated values never affect layout.
Item {
  id: root
  objectName: "hoverIndex"
  required property Design.Theme tokens
  property bool vertical: false
  property bool rightEdge: false
  property bool animate: tokens.settings.value.animations
  property color ink: tokens.cyan
  readonly property int thickness: 2
  property real origin: 0
  property real extent: 0
  property real destination: 0
  property real destinationExtent: 0
  property bool active: false
  opacity: 0
  onActiveChanged: {
    fade.stop();
    fade.to = active ? 1 : 0;
    if (animate) fade.start();
    else opacity = active ? 1 : 0;
  }
  NumberAnimation { id: fade; target: root; property: "opacity"; to: 0; duration: 140 }
  function retarget(start: real, length: real): void {
    if (active && destination === start && destinationExtent === length) return;
    movement.stop();
    destination = start;
    destinationExtent = length;
    var wasActive = active;
    active = true;
    if (!animate) { origin = start; extent = length; return; }
    if (!wasActive && opacity === 0) origin = start;
    movement.start();
  }
  function clear(): void {
    if (!active) return;
    movement.stop();
    active = false;
    if (animate) departure.start();
    else extent = 0;
  }
  onAnimateChanged: {
    fade.stop();
    opacity = active ? 1 : 0;
    movement.stop();
    departure.stop();
    origin = destination;
    extent = active ? destinationExtent : 0;
  }
  SequentialAnimation {
    id: movement
    onStarted: departure.stop()
    NumberAnimation { target: root; property: "extent"; to: 0; duration: 70 }
    NumberAnimation { target: root; property: "origin"; to: root.destination; duration: 70; easing.type: Easing.InOutCubic }
    NumberAnimation { target: root; property: "extent"; objectName: "hoverExtension"; to: root.destinationExtent; duration: 450; easing.type: Easing.OutCubic }
  }
  NumberAnimation { id: departure; target: root; property: "extent"; to: 0; duration: 140 }
  Rectangle {
    objectName: "hoverLine"
    x: root.vertical ? (root.rightEdge ? root.width - 5 - root.thickness : 5) : root.origin
    y: root.vertical ? root.origin : 5
    width: root.vertical ? root.thickness : root.extent
    height: root.vertical ? root.extent : root.thickness
    color: root.tokens.settings.value.mode === "light" ? Qt.darker(root.ink, 1.7) : root.ink
  }
  Rectangle {
    objectName: "hoverVermilion"
    x: root.vertical ? (root.rightEdge ? root.width - 8 : 5) : root.origin - 3
    y: root.vertical ? root.origin - 3 : 5
    width: 3; height: 3
    color: root.tokens.alert
  }
}
