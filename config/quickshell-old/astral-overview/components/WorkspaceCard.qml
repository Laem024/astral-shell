pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "."

Item {
  id: root
  required property var tokens
  required property var overview
  required property var workspace
  property bool previews: true
  property bool dropTarget: false
  property string draggingAddress: ""
  property var monitors: []
  property real uniformHeight: 0
  property int tileHeight: 88
  property bool monitorMenuOpen: false

  signal workspaceActivated()
  signal windowActivated(string address)
  signal monitorChangeRequested(string monitorName)
  signal windowDragStarted(int workspaceId, string address, string title, string appId, var scenePosition)
  signal windowDragMoved(var scenePosition)
  signal windowDragFinished(var scenePosition)

  readonly property bool workspaceSelected: !!overview.selectedWorkspace
    && overview.selectedWorkspace.id === workspace.id
  readonly property int cardPadding: 12
  readonly property int headerHeight: 38
  readonly property int cardGap: 8
  readonly property int columns: width >= 280 ? 2 : 1
  readonly property int contentHeight: Math.max(tileHeight,
    (uniformHeight > 0 ? uniformHeight : implicitHeight)
      - 2 * cardPadding - headerHeight - cardGap)
  readonly property int fitRows: Math.max(1,
    Math.floor((contentHeight + cardGap) / (tileHeight + cardGap)))
  readonly property int capacity: fitRows * columns
  readonly property int shownCount: Math.min(workspace.windows.length, capacity)
  readonly property int hiddenCount: Math.max(0, workspace.windows.length - shownCount)
  readonly property int tileWidth: Math.max(72,
    Math.floor((width - 2 * cardPadding - (columns - 1) * cardGap) / columns))
  readonly property int usedRows: Math.max(1, Math.ceil(shownCount / columns))
  readonly property int usedHeight: usedRows * tileHeight + (usedRows - 1) * cardGap
  readonly property bool canMoveMonitor: workspace.exists && monitors.length > 1
  readonly property string monitorLabel: workspace.monitorName
    ? workspace.monitorName : "—"
  readonly property bool hovered: cardHover.hovered

  implicitHeight: uniformHeight > 0 ? uniformHeight : 200
  height: implicitHeight
  z: monitorMenuOpen ? 60 : (workspaceSelected ? 4 : (workspace.current ? 2 : 0))

  onWorkspaceChanged: monitorMenuOpen = false

  Rectangle {
    id: background
    anchors.fill: parent
    radius: 16
    color: "transparent"
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop {
        position: 0
        color: root.hovered ? Qt.alpha(root.tokens.surface, 1)
          : Qt.alpha(root.tokens.surface, 0.97)
      }
      GradientStop {
        position: 1
        color: root.hovered ? Qt.alpha(root.tokens.background, 0.97)
          : Qt.alpha(root.tokens.background, 0.94)
      }
    }
    border.width: root.dropTarget ? 2 : root.workspaceSelected || root.workspace.current ? 1.5 : 1
    border.color: root.dropTarget || root.workspaceSelected ? root.tokens.cyan
      : root.workspace.current ? root.tokens.gold
      : root.hovered ? Qt.alpha(root.tokens.cyan, 0.34)
      : root.tokens.border
    Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }

    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: root.dropTarget ? Qt.alpha(root.tokens.cyan, 0.10)
        : root.workspaceSelected ? Qt.alpha(root.tokens.cyan, 0.08)
        : "transparent"
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
    }

    Rectangle {
      visible: root.workspace.current
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.topMargin: 1
      width: Math.min(52, parent.width * 0.24)
      height: 2
      radius: 1
      color: root.tokens.gold
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: root.dropTarget ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: root.workspaceActivated()
  }

  HoverHandler { id: cardHover }

  RowLayout {
    id: header
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      leftMargin: root.cardPadding
      rightMargin: root.cardPadding
      topMargin: root.cardPadding
    }
    height: root.headerHeight
    spacing: 9

    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: root.workspace.id > 99 ? 40 : 34
      implicitHeight: 34
      radius: 10
      color: root.workspace.current ? Qt.alpha(root.tokens.gold, 0.14)
        : root.workspaceSelected ? Qt.alpha(root.tokens.cyan, 0.14)
        : Qt.alpha(root.tokens.muted, 0.08)
      border.width: 1
      border.color: root.workspace.current ? Qt.alpha(root.tokens.gold, 0.35)
        : root.workspaceSelected ? Qt.alpha(root.tokens.cyan, 0.35)
        : Qt.alpha(root.tokens.muted, 0.14)
      Text {
        anchors.centerIn: parent
        text: String(root.workspace.id)
        color: root.workspace.current ? root.tokens.gold : root.tokens.text
        font.family: root.tokens.mono
        font.pixelSize: root.workspace.id > 99 ? 15 : 18
        font.weight: Font.DemiBold
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      Layout.alignment: Qt.AlignVCenter
      spacing: 1
      Text {
        Layout.fillWidth: true
        text: root.workspace.current ? "CURRENT"
          : root.workspaceSelected ? "SELECTED" : "SPACE"
        color: root.workspace.current ? root.tokens.gold
          : root.workspaceSelected ? root.tokens.cyan : root.tokens.muted
        elide: Text.ElideRight
        font.family: root.tokens.mono
        font.pixelSize: 8
        font.letterSpacing: 1.2
      }
      Text {
        Layout.fillWidth: true
        text: root.workspace.windows.length === 0
          ? "No windows"
          : root.workspace.windows.length
            + (root.workspace.windows.length === 1 ? " window" : " windows")
        color: Qt.alpha(root.tokens.muted, root.workspace.windows.length ? 0.95 : 0.6)
        elide: Text.ElideRight
        font.family: root.tokens.font
        font.pixelSize: 10
      }
    }

    Rectangle {
      id: monitorChip
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: chipRow.implicitWidth + 16
      implicitHeight: 24
      radius: 12
      color: root.monitorMenuOpen ? Qt.alpha(root.tokens.cyan, 0.18)
        : chipHover.hovered && root.canMoveMonitor ? Qt.alpha(root.tokens.cyan, 0.10)
        : "transparent"
      border.width: 1
      border.color: root.monitorMenuOpen || (chipHover.hovered && root.canMoveMonitor)
        ? Qt.alpha(root.tokens.cyan, 0.40) : Qt.alpha(root.tokens.muted, 0.18)
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }

      Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 5
        Text {
          text: "▣"
          color: root.canMoveMonitor ? root.tokens.cyan : Qt.alpha(root.tokens.muted, 0.7)
          font.family: root.tokens.mono
          font.pixelSize: 9
        }
        Text {
          text: root.monitorLabel
          color: root.canMoveMonitor ? root.tokens.text : Qt.alpha(root.tokens.muted, 0.8)
          elide: Text.ElideRight
          width: Math.min(implicitWidth, 92)
          font.family: root.tokens.mono
          font.pixelSize: 8
        }
        Text {
          visible: root.canMoveMonitor
          text: "⌄"
          color: Qt.alpha(root.tokens.cyan, 0.9)
          font.pixelSize: 10
        }
      }

      HoverHandler { id: chipHover }
      MouseArea {
        anchors.fill: parent
        enabled: root.canMoveMonitor
        cursorShape: root.canMoveMonitor ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.monitorMenuOpen = !root.monitorMenuOpen
      }
    }
  }

  Item {
    id: tileArea
    anchors {
      left: parent.left
      right: parent.right
      top: header.bottom
      bottom: parent.bottom
      leftMargin: root.cardPadding
      rightMargin: root.cardPadding
      topMargin: root.cardGap
      bottomMargin: root.cardPadding
    }
    clip: true

    Grid {
      id: tiles
      width: parent.width
      columns: root.columns
      spacing: root.cardGap
      y: Math.max(0, (root.contentHeight - root.usedHeight) / 2)

      Repeater {
        model: root.workspace.windows.slice(0, root.shownCount)
        delegate: WindowTile {
          required property var modelData
          width: root.tileWidth
          height: root.tileHeight
          tokens: root.tokens
          windowData: modelData
          previews: root.previews
          live: root.previews && root.workspace.id === root.overview.activeId
          dragging: root.draggingAddress !== "" && root.draggingAddress === modelData.address
          onActivated: root.windowActivated(modelData.address)
          onDragStarted: scenePosition => root.windowDragStarted(root.workspace.id,
            modelData.address, modelData.title, modelData.appId, scenePosition)
          onDragMoved: scenePosition => root.windowDragMoved(scenePosition)
          onDragFinished: scenePosition => root.windowDragFinished(scenePosition)
        }
      }
    }

    Rectangle {
      visible: root.hiddenCount > 0
      anchors {
        right: parent.right
        bottom: parent.bottom
      }
      width: hiddenLabel.implicitWidth + 14
      height: 20
      radius: 10
      color: Qt.alpha(root.tokens.background, 0.94)
      border.width: 1
      border.color: Qt.alpha(root.tokens.cyan, 0.35)
      Text {
        id: hiddenLabel
        anchors.centerIn: parent
        text: "+" + root.hiddenCount
        color: root.tokens.cyan
        font.family: root.tokens.mono
        font.pixelSize: 8
        font.weight: Font.DemiBold
      }
    }
  }

  Column {
    visible: root.workspace.windows.length === 0
    width: tileArea.width
    anchors {
      horizontalCenter: tileArea.horizontalCenter
      verticalCenter: tileArea.verticalCenter
    }
    spacing: 5
    Text {
      text: root.dropTarget ? "DROP HERE" : "NO WINDOWS"
      color: root.dropTarget ? root.tokens.cyan : Qt.alpha(root.tokens.muted, 0.7)
      font.family: root.tokens.mono
      font.pixelSize: 10
      font.letterSpacing: 1.8
    }
    Text {
      text: root.workspace.current ? "Active space" : "Click to open"
      color: Qt.alpha(root.tokens.muted, 0.75)
      font.family: root.tokens.font
      font.pixelSize: 10
    }
  }

  // Monitor picker: lives inside the card so it never escapes the overview surface.
  Rectangle {
    id: monitorMenu
    visible: root.monitorMenuOpen
    z: 80
    width: 170
    height: menuColumn.implicitHeight + 12
    x: parent.width - width - root.cardPadding
    y: root.cardPadding + root.headerHeight + 4
    radius: 10
    color: Qt.alpha(root.tokens.surface, 0.99)
    border.width: 1
    border.color: Qt.alpha(root.tokens.cyan, 0.38)

    Column {
      id: menuColumn
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        margins: 6
      }
      spacing: 2

      Text {
        leftPadding: 6
        text: "MOVE TO MONITOR"
        color: Qt.alpha(root.tokens.muted, 0.85)
        font.family: root.tokens.mono
        font.pixelSize: 7
        font.letterSpacing: 1.1
      }

      Repeater {
        model: root.monitors
        delegate: Rectangle {
          id: option
          required property var modelData
          width: menuColumn.width
          height: 28
          radius: 7
          color: optionHover.hovered ? Qt.alpha(root.tokens.cyan, 0.12) : "transparent"

          HoverHandler { id: optionHover }

          RowLayout {
            anchors {
              fill: parent
              leftMargin: 6
              rightMargin: 6
            }
            spacing: 6
            Text {
              Layout.alignment: Qt.AlignVCenter
              text: option.modelData.name === root.workspace.monitorName ? "✓" : " "
              color: root.tokens.cyan
              font.family: root.tokens.mono
              font.pixelSize: 9
            }
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              text: option.modelData.name
              color: option.modelData.name === root.workspace.monitorName
                ? root.tokens.cyan : root.tokens.text
              elide: Text.ElideRight
              font.family: root.tokens.mono
              font.pixelSize: 9
            }
            Text {
              Layout.alignment: Qt.AlignVCenter
              visible: option.modelData.focused
              text: "FOCUS"
              color: Qt.alpha(root.tokens.muted, 0.8)
              font.family: root.tokens.mono
              font.pixelSize: 7
              font.letterSpacing: 0.8
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.monitorMenuOpen = false;
              root.monitorChangeRequested(option.modelData.name);
            }
          }
        }
      }
    }
  }

  // Drop affordance: drawn above the tiles so the target card reads clearly.
  Rectangle {
    visible: root.dropTarget
    anchors.fill: parent
    radius: 16
    color: "transparent"
    border.width: 2
    border.color: root.tokens.cyan
    z: 10
  }
  Rectangle {
    visible: root.dropTarget
    anchors.centerIn: parent
    width: 152
    height: 32
    radius: 16
    color: root.tokens.cyan
    z: 11
    Text {
      anchors.centerIn: parent
      text: "MOVE HERE"
      color: root.tokens.background
      font.family: root.tokens.mono
      font.pixelSize: 9
      font.letterSpacing: 1.2
    }
  }
}
