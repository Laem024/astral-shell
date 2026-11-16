pragma ComponentBehavior: Bound
import "../common" as Common
import QtQuick
import QtQuick.Layouts
import Quickshell
import "components" as Components
import "Logic.js" as Logic

FocusScope {
  id: root
  required property var tokens
  required property var overview
  property bool active: false
  property bool previews: true
  readonly property int gap: 14
  readonly property int tileHeight: 80
  readonly property real stripWidth: Math.max(0, width - 2 * (tokens.inset + 8))
  readonly property int visibleCards: Math.max(2, Math.min(10, Math.floor(stripWidth / 300)))
  readonly property real cardWidth: Math.max(240, Math.min(380,
    (stripWidth - (visibleCards - 1) * gap) / visibleCards))
  readonly property real cardHeight: Math.max(250, Math.min(290, Math.round(height * 0.30)))

  property bool dragging: false
  property string dragAddress: ""
  property string dragTitle: ""
  property string dragAppId: ""
  property int dragWorkspaceId: 0
  property point dragPoint: Qt.point(0, 0)
  property int dropWorkspaceId: -1

  signal activateRequested()
  signal activateWorkspaceRequested(int workspaceId)
  signal activateWindowRequested(string address)
  signal moveWorkspaceToMonitorRequested(int workspaceId, string monitorName)
  signal cancelRequested()

  function reset(): void {
    forceActiveFocus();
    Qt.callLater(ensureVisible);
  }

  function ensureVisible(): void {
    const card = cards.itemAt(overview.selectedIndex);
    if (!card) return;
    const left = carousel.x + card.x;
    const target = left - (flick.width - card.width) / 2;
    flick.contentX = Math.min(Math.max(0, target),
      Math.max(0, flick.contentWidth - flick.width));
  }

  function beginDrag(workspaceId, address, title, appId, scenePosition): void {
    dragging = true;
    dragWorkspaceId = workspaceId;
    dragAddress = address;
    dragTitle = title;
    dragAppId = appId;
    updateDrag(scenePosition);
  }

  function updateDrag(scenePosition): void {
    dragPoint = root.mapFromItem(null, scenePosition.x, scenePosition.y);
    dropWorkspaceId = workspaceAt();
  }

  function finishDrag(scenePosition): void {
    if (!dragging) return;
    updateDrag(scenePosition);
    const target = dropWorkspaceId;
    const address = dragAddress;
    const source = dragWorkspaceId;
    cancelDrag();
    if (target > 0 && target !== source)
      overview.moveWindow(address, target);
  }

  function cancelDrag(): void {
    dragging = false;
    dragAddress = "";
    dragTitle = "";
    dragAppId = "";
    dragWorkspaceId = 0;
    dropWorkspaceId = -1;
  }

  function workspaceRects(): var {
    const rects = [];
    for (let index = 0; index < cards.count; index++) {
      const card = cards.itemAt(index);
      const workspace = root.overview.workspaces[index];
      if (!card || !workspace) continue;
      const origin = root.mapFromItem(card, 0, 0);
      rects.push({
        id: workspace.id,
        x: origin.x,
        y: origin.y,
        width: card.width,
        height: card.height
      });
    }
    return rects;
  }

  function workspaceAt(): int {
    return Logic.dropTarget(dragPoint, workspaceRects(), dragWorkspaceId);
  }

  onActiveChanged: {
    if (active) Qt.callLater(() => { if (root.active) root.reset(); });
    else root.cancelDrag();
  }

  // The panel starts at 1x1 and adopts the monitor size when it opens; recenter
  // the selection then, or contentX keeps the value computed for the tiny size.
  onWidthChanged: {
    if (active) Qt.callLater(ensureVisible);
  }

  Connections {
    target: root.overview
    function onSelectedIndexChanged(): void { Qt.callLater(root.ensureVisible); }
    function onWorkspacesChanged(): void {
      if (root.dragging && !root.overview.workspaces.some(space => space.windows.some(window => window.address === root.dragAddress))) root.cancelDrag();
    }
    function onMonitorsChanged(): void { root.cancelDrag(); }
  }

  Keys.onPressed: event => {
    if (event.key === Qt.Key_Escape) {
      if (root.dragging) root.cancelDrag();
      else root.cancelRequested();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      root.activateRequested();
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Tab) {
      root.overview.selectRelative((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
      root.overview.selectRelative(-1);
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
      root.overview.selectRelative(1);
      event.accepted = true;
    }
  }

  Keys.onReleased: event => {
    if (event.isAutoRepeat) return;
    if (event.key === Qt.Key_Alt) {
      // Keep the view open while a window is being dragged, so Alt can be
      // released before the drop without cancelling the move.
      if (root.dragging) return;
      root.activateRequested();
      event.accepted = true;
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.cancelRequested()
  }

  Column {
    id: chrome
    anchors {
      top: parent.top
      left: parent.left
      right: parent.right
      topMargin: root.tokens.inset + 8
      leftMargin: root.tokens.inset + 8
      rightMargin: root.tokens.inset + 8
    }
    spacing: 10

    RowLayout {
      width: chrome.width
      height: 36
      spacing: 10

      Rectangle {
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 10
        color: Qt.alpha(root.tokens.cyan, 0.10)
        border.width: 1
        border.color: Qt.alpha(root.tokens.cyan, 0.26)
        Text {
          anchors.centerIn: parent
          text: "⌘"
          color: root.tokens.cyan
          font.family: root.tokens.mono
          font.pixelSize: 18
        }
      }

      Text {
        Layout.alignment: Qt.AlignVCenter
        text: "Spaces"
        color: root.tokens.text
        font.family: root.tokens.font
        font.pixelSize: 18
        font.weight: Font.DemiBold
      }

      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 1
        Layout.preferredHeight: 18
        color: root.tokens.border
      }

      Text {
        Layout.alignment: Qt.AlignVCenter
        text: "Block " + (root.overview.blockStart + 1) + "–" + root.overview.blockEnd
          + "  ·  " + root.overview.windowTotal
          + (root.overview.windowTotal === 1 ? " window" : " windows")
        color: root.tokens.muted
        elide: Text.ElideRight
        font.family: root.tokens.mono
        font.pixelSize: 9
      }

      Item { Layout.fillWidth: true }

      Rectangle {
        visible: !!root.overview.selectedWorkspace
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredHeight: 24
        Layout.preferredWidth: selectionLabel.width + 20
        radius: 12
        color: Qt.alpha(root.tokens.cyan, 0.10)
        border.width: 1
        border.color: Qt.alpha(root.tokens.cyan, 0.30)
        Text {
          id: selectionLabel
          anchors.centerIn: parent
          text: root.overview.selectedWorkspace
            ? "SPACE " + root.overview.selectedWorkspace.id : ""
          color: root.tokens.cyan
          font.family: root.tokens.mono
          font.pixelSize: 8
          font.letterSpacing: 1.1
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        radius: 14
        color: closeHover.hovered ? Qt.alpha(root.tokens.muted, 0.14) : "transparent"
        border.width: 1
        border.color: Qt.alpha(root.tokens.muted, 0.22)
        Text {
          anchors.centerIn: parent
          text: "×"
          color: root.tokens.muted
          font.pixelSize: 18
        }
        HoverHandler { id: closeHover }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.cancelRequested()
        }
      }
    }

    Rectangle {
      width: chrome.width
      implicitHeight: 1
      color: root.tokens.border
    }

    Flickable {
      id: flick
      width: chrome.width
      height: root.cardHeight
      contentWidth: Math.max(width, carousel.width)
      contentHeight: height
      clip: true
      interactive: !root.dragging
      flickableDirection: Flickable.HorizontalFlick
      boundsBehavior: Flickable.StopAtBounds

      Behavior on contentX {
        enabled: !flick.moving && !root.dragging
        NumberAnimation { duration: root.tokens.hoverDuration; easing.type: Easing.OutCubic }
      }

      Item {
        id: carousel
        // Explicit positions: Row keeps stale positions when the card width
        // changes, which pushed the cards off the strip after the first layout.
        width: cards.count > 0
          ? cards.count * root.cardWidth + (cards.count - 1) * root.gap : 0
        height: root.cardHeight
        x: Math.max(0, (flick.width - width) / 2)

        Repeater {
          id: cards
          model: root.overview.workspaces
          delegate: Components.WorkspaceCard {
            required property var modelData
            required property int index
            x: index * (root.cardWidth + root.gap)
            y: 0
            width: root.cardWidth
            uniformHeight: root.cardHeight
            tileHeight: root.tileHeight
            tokens: root.tokens
            overview: root.overview
            workspace: modelData
            previews: root.previews
            monitors: root.overview.monitors
            dropTarget: root.dragging && root.dropWorkspaceId === modelData.id
            draggingAddress: root.dragAddress
            onWorkspaceActivated: root.activateWorkspaceRequested(modelData.id)
            onWindowActivated: address => root.activateWindowRequested(address)
            onMonitorChangeRequested: monitorName =>
              root.moveWorkspaceToMonitorRequested(modelData.id, monitorName)
            onWindowDragStarted: (workspaceId, address, title, appId, scenePosition) =>
              root.beginDrag(workspaceId, address, title, appId, scenePosition)
            onWindowDragMoved: scenePosition => root.updateDrag(scenePosition)
            onWindowDragFinished: scenePosition => root.finishDrag(scenePosition)
          }
        }
      }
    }

    RowLayout {
      width: chrome.width
      spacing: 16
      Components.KeyHint { tokens: root.tokens; key: "TAB"; label: "spaces" }
      Components.KeyHint { tokens: root.tokens; key: "ENTER"; label: "open" }
      Components.KeyHint { tokens: root.tokens; key: "DRAG"; label: "move windows" }
      Components.KeyHint { tokens: root.tokens; key: "▣"; label: "change monitor" }
      Components.KeyHint { tokens: root.tokens; key: "ESC"; label: "close" }
      Item { Layout.fillWidth: true }
      Text {
        text: "Release Alt to open the space"
        color: Qt.alpha(root.tokens.muted, 0.8)
        font.family: root.tokens.font
        font.pixelSize: 10
      }
    }
  }

  Rectangle {
    id: dragGhost
    visible: root.dragging
    z: 100
    width: 220
    height: 62
    radius: 12
    x: Math.max(8, Math.min(root.width - width - 8, root.dragPoint.x - width / 2))
    y: Math.max(8, Math.min(root.height - height - 8, root.dragPoint.y - height / 2))
    color: Qt.alpha(root.tokens.surface, 0.97)
    border.width: 1.5
    border.color: root.dropWorkspaceId > 0
      ? root.tokens.cyan : Qt.alpha(root.tokens.cyan, 0.45)
    opacity: 0.97

    RowLayout {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 10
      Image {
        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        sourceSize.width: 30
        sourceSize.height: 30
        source: Quickshell.iconPath(root.dragAppId, "application-x-executable")
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 1
        Text {
          Layout.fillWidth: true
          text: root.dragTitle || "Window"
          color: root.tokens.text
          elide: Text.ElideRight
          maximumLineCount: 1
          font.family: root.tokens.font
          font.pixelSize: 11
          font.weight: Font.DemiBold
        }
        Text {
          Layout.fillWidth: true
          text: root.dropWorkspaceId > 0
            ? "Move to space " + root.dropWorkspaceId : "Drag to another space"
          color: root.dropWorkspaceId > 0 ? root.tokens.cyan : root.tokens.muted
          elide: Text.ElideRight
          maximumLineCount: 1
          font.family: root.tokens.mono
          font.pixelSize: 8
          font.letterSpacing: 0.4
        }
      }
    }
  }
}
