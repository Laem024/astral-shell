pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root
  required property var tokens
  required property var windowData
  property bool previews: true
  property bool live: false
  property bool dragging: false
  property bool pointerDragging: false
  readonly property bool hovered: mouse.containsMouse
  signal activated()
  signal dragStarted(var scenePosition)
  signal dragMoved(var scenePosition)
  signal dragFinished(var scenePosition)

  property bool pressed: false
  property real pressX: 0
  property real pressY: 0

  Accessible.role: Accessible.Button
  Accessible.name: windowData ? windowData.title : "Window"

  function scenePoint(x, y): var {
    return root.mapToItem(null, x, y);
  }

  Rectangle {
    id: card
    anchors.fill: parent
    radius: 10
    color: "transparent"
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop {
        position: 0
        color: root.hovered && !root.dragging
          ? Qt.alpha(root.tokens.cyan, 0.13) : Qt.alpha(root.tokens.background, 0.58)
      }
      GradientStop {
        position: 1
        color: root.hovered && !root.dragging
          ? Qt.alpha(root.tokens.cyan, 0.07) : Qt.alpha(root.tokens.background, 0.72)
      }
    }
    border.width: root.hovered ? 1.5 : 1
    border.color: root.hovered ? Qt.alpha(root.tokens.cyan, 0.70)
      : Qt.alpha(root.tokens.muted, 0.16)
    opacity: root.dragging ? 0.35 : 1
    clip: true
    Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
    Behavior on opacity { NumberAnimation { duration: root.tokens.hoverDuration } }

    Rectangle {
      id: previewFrame
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        margins: 4
      }
      height: Math.max(20, parent.height - 36)
      radius: 7
      color: Qt.alpha(root.tokens.surface, 0.92)
      clip: true

      Image {
        id: icon
        anchors.centerIn: parent
        width: 26
        height: 26
        sourceSize.width: 26
        sourceSize.height: 26
        source: Quickshell.iconPath(root.windowData ? root.windowData.appId : "",
          "application-x-executable")
        visible: !preview.hasContent || !root.previews
        opacity: root.hovered ? 1 : 0.75
      }
      ScreencopyView {
        id: preview
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        constraintSize: Qt.size(previewFrame.width, previewFrame.height)
        captureSource: root.previews && root.windowData ? root.windowData.capture : null
        live: root.live
        visible: root.previews
      }
    }

    Column {
      anchors {
        left: parent.left
        right: parent.right
        bottom: parent.bottom
        leftMargin: 7
        rightMargin: 7
        bottomMargin: 6
      }
      spacing: 0
      Text {
        width: parent.width
        text: root.windowData ? root.windowData.title : "Untitled"
        color: root.hovered ? root.tokens.text : root.tokens.muted
        elide: Text.ElideRight
        maximumLineCount: 1
        font.family: root.tokens.font
        font.pixelSize: 10
        font.weight: root.hovered ? Font.DemiBold : Font.Normal
      }
      Text {
        width: parent.width
        text: root.windowData && root.windowData.appId
          ? root.windowData.appId : "Window"
        color: Qt.alpha(root.tokens.muted, 0.68)
        elide: Text.ElideRight
        maximumLineCount: 1
        font.family: root.tokens.mono
        font.pixelSize: 8
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.pointerDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

    onPressed: mouse => {
      root.pressed = true;
      root.pressX = mouse.x;
      root.pressY = mouse.y;
    }
    onPositionChanged: mouse => {
      if (!root.pressed) return;
      if (!root.pointerDragging) {
        const dx = mouse.x - root.pressX;
        const dy = mouse.y - root.pressY;
        if (dx * dx + dy * dy < 64) return;
        root.pointerDragging = true;
        root.dragStarted(root.scenePoint(mouse.x, mouse.y));
      }
      root.dragMoved(root.scenePoint(mouse.x, mouse.y));
    }
    onReleased: mouse => {
      if (root.pointerDragging) root.dragFinished(root.scenePoint(mouse.x, mouse.y));
      else root.activated();
      root.pressed = false;
      root.pointerDragging = false;
    }
    onCanceled: {
      root.pressed = false;
      root.pointerDragging = false;
    }
  }
}
