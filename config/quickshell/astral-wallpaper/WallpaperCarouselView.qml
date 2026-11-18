pragma ComponentBehavior: Bound
import QtQuick
import "../common" as Common

// Cinematic coverflow used by the quick wallpaper selector. It is a plain Item
// so tests can render it without a Wayland layershell.
Item {
  id: root
  required property var service
  required property var tokens
  property string monitorName: ""
  property bool active: false
  property int currentIndex: -1
  readonly property var items: service.available
  readonly property var current: currentIndex >= 0 && currentIndex < items.length ? items[currentIndex] : null
  readonly property real cardWidth: Math.max(150, Math.min(560, width * 0.44, (stage.height - 36) / 0.62))
  readonly property real cardHeight: Math.round(cardWidth * 0.62)
  readonly property real delegateWidth: cardWidth + 30
  readonly property real spacerWidth: Math.max(0, (width - delegateWidth) / 2)
  readonly property string collection: service.collection ? service.collection.toUpperCase() : ""
  readonly property bool light: tokens.background.hslLightness > 0.5
  readonly property string activePath: (service.activePaths || {})[monitorName] || ""
  signal closeRequested()

  focus: true
  function pad(value) { return (value < 10 ? "0" : "") + value; }
  function center() { if (root.currentIndex >= 0 && root.currentIndex < root.items.length) strip.positionViewAtIndex(root.currentIndex, ListView.Center); }
  function reset() {
    const path = root.monitorName ? (root.service.activePaths || {})[root.monitorName] : "";
    const index = root.items.findIndex(e => e.path === path);
    root.currentIndex = index >= 0 ? index : (root.items.length ? 0 : -1);
    Qt.callLater(root.center);
  }
  function move(delta) {
    const count = root.items.length;
    if (!count) return;
    // Wrap around both ends so the strip loops instead of stopping at the
    // first or last wallpaper.
    const from = root.currentIndex >= 0 ? root.currentIndex : 0;
    root.currentIndex = ((from + delta) % count + count) % count;
    root.center();
  }
  function applyCurrent() {
    if (!root.active || !root.current || root.service.scanning || root.service.transaction || root.service.blocked) return;
    const monitor = root.monitorName || (root.service.screens.length ? root.service.screens[0].name : "");
    if (!monitor) return;
    root.service.apply(root.current.path, monitor, root.service.state.layout);
    root.closeRequested();
  }
  onItemsChanged: {
    if (!root.active) return;
    if (!root.items.length) { root.currentIndex = -1; return; }
    root.currentIndex = Math.max(0, Math.min(root.currentIndex, root.items.length - 1));
    Qt.callLater(root.center);
  }
  onActiveChanged: if (root.active) Qt.callLater(root.reset)
  onWidthChanged: if (root.currentIndex >= 0) Qt.callLater(root.center)
  onHeightChanged: if (root.currentIndex >= 0) Qt.callLater(root.center)
  Keys.onPressed: event => {
    if (event.key === Qt.Key_Left) { root.move(-1); event.accepted = true; }
    else if (event.key === Qt.Key_Right) { root.move(1); event.accepted = true; }
    else if (event.key === Qt.Key_Home) { root.currentIndex = root.items.length ? 0 : -1; root.center(); event.accepted = true; }
    else if (event.key === Qt.Key_End) { root.currentIndex = root.items.length - 1; root.center(); event.accepted = true; }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { root.applyCurrent(); event.accepted = true; }
    else if (event.key === Qt.Key_Escape) { root.closeRequested(); event.accepted = true; }
  }

  // Ambient backdrop: the current wallpaper, dimmed and scrimmed so the
  // filmstrip stays legible over any image. A plain Image keeps this working
  // on software and GPU renderers alike.
  Item {
    anchors.fill: parent
    clip: true
    opacity: root.current ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: root.tokens.entryDuration } }
    Thumbnail {
      anchors.fill: parent
      anchors.margins: -70
      service: root.service
      path: root.current ? root.current.path : ""
      sourceSize.width: 960
      opacity: root.light ? 0.26 : 0.4
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.alpha(root.tokens.background, 0.60) }
        GradientStop { position: 0.42; color: Qt.alpha(root.tokens.background, 0.80) }
        GradientStop { position: 1.0; color: root.tokens.background }
      }
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.alpha(root.tokens.background, 0.55) }
        GradientStop { position: 0.28; color: "transparent" }
        GradientStop { position: 0.72; color: "transparent" }
        GradientStop { position: 1.0; color: Qt.alpha(root.tokens.background, 0.55) }
      }
    }
  }

  Item {
    id: header
    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 26; leftMargin: 30; rightMargin: 30 }
    height: 38
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      Rectangle {
        width: 8; height: 8; radius: 2
        color: root.tokens.cyan
        rotation: 45
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "ASTRAL"
        color: root.tokens.text
        font.family: root.tokens.font
        font.pixelSize: 10; font.bold: true; font.letterSpacing: 3
        anchors.verticalCenter: parent.verticalCenter
      }
      Rectangle {
        width: 1; height: 12
        color: root.tokens.border
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: "WALLPAPERS"
        color: root.tokens.muted
        font.family: root.tokens.font
        font.pixelSize: 10; font.bold: true; font.letterSpacing: 3
        anchors.verticalCenter: parent.verticalCenter
      }
    }
    Row {
      anchors { right: closeButton.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
      spacing: 8
      Rectangle {
        width: collectionLabel.implicitWidth + 20; height: 24; radius: 12
        color: Qt.alpha(root.tokens.cyan, 0.10)
        border.width: 1
        border.color: Qt.alpha(root.tokens.cyan, 0.30)
        Text {
          id: collectionLabel
          anchors.centerIn: parent
          text: root.collection
          color: root.tokens.cyan
          font.family: root.tokens.font
          font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
        }
      }
      Rectangle {
        visible: root.monitorName.length > 0
        width: monitorRow.implicitWidth + 20; height: 24; radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.tokens.border
        Row {
          id: monitorRow
          anchors.centerIn: parent
          spacing: 6
          Rectangle {
            width: 5; height: 5; radius: 2.5
            color: root.tokens.gold
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: root.monitorName
            color: root.tokens.muted
            font.family: root.tokens.font
            font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
          }
        }
      }
    }
    Rectangle {
      id: closeButton
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      width: 34; height: 34; radius: 17
      color: closeHover.hovered ? Qt.alpha(root.tokens.text, 0.08) : "transparent"
      border.width: 1
      border.color: closeHover.hovered ? Qt.alpha(root.tokens.text, 0.22) : root.tokens.border
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
      Text {
        anchors.centerIn: parent
        text: "✕"
        color: closeHover.hovered ? root.tokens.text : root.tokens.muted
        font.family: root.tokens.font
        font.pixelSize: 12
      }
      HoverHandler { id: closeHover }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.closeRequested()
        Accessible.role: Accessible.Button
        Accessible.name: "Close wallpaper carousel"
      }
    }
  }

  Item {
    id: stage
    objectName: "wallpaperCarouselStage"
    anchors {
      top: header.bottom; topMargin: 12
      left: parent.left; right: parent.right
      bottom: footer.top; bottomMargin: 18
    }
    clip: true

    ListView {
      id: strip
      objectName: "wallpaperCarouselStrip"
      anchors.fill: parent
      orientation: ListView.Horizontal
      model: root.items
      currentIndex: root.currentIndex
      interactive: false
      clip: true
      spacing: -root.cardWidth * 0.36
      cacheBuffer: root.cardWidth * 3
      boundsBehavior: Flickable.StopAtBounds
      // Keep the first and last card centered instead of pinned to the edges.
      header: Item { width: root.spacerWidth; height: 1 }
      footer: Item { width: root.spacerWidth; height: 1 }
      Behavior on contentX {
        enabled: root.active
        NumberAnimation { duration: root.tokens.workspaceDuration; easing.type: Easing.OutCubic }
      }
      delegate: Item {
        id: tile
        required property var modelData
        required property int index
        readonly property int distance: Math.abs(index - root.currentIndex)
        readonly property bool selected: index === root.currentIndex
        readonly property bool inUse: root.activePath === modelData.path
        readonly property string kind: (modelData.kind || "").toLowerCase()
        width: root.delegateWidth
        height: strip.height
        z: 100 - tile.distance

        Item {
          id: holder
          // Flatten before perspective, with transparent texels around the
          // card so filtering can soften its outer silhouette as well.
          layer.enabled: true
          layer.smooth: true
          layer.sourceRect: Qt.rect(-16, -16, width + 32, height + 32)
          layer.textureSize: Qt.size(Math.ceil((width + 32) * 2), Math.ceil((height + 32) * 2))
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.cardWidth
          height: root.cardHeight
          y: Math.round((strip.height - height) / 2) + (tile.selected ? 0 : Math.min(26, 6 + tile.distance * 5))
          scale: (tile.selected ? 1 : Math.max(0.58, 0.82 - (tile.distance - 1) * 0.08)) * (cardHover.hovered && !tile.selected ? 1.04 : 1)
          opacity: tile.selected ? 1 : Math.max(0, (root.light ? 0.72 : 0.55) - (tile.distance - 1) * 0.18)
          transform: Rotation {
            origin.x: holder.width / 2
            origin.y: holder.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: tile.selected ? 0 : Math.max(-26, Math.min(26, (tile.index - root.currentIndex) * -9))
            Behavior on angle { NumberAnimation { duration: root.tokens.workspaceDuration; easing.type: Easing.OutCubic } }
          }
          Behavior on scale { NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic } }
          Behavior on y { NumberAnimation { duration: root.tokens.workspaceDuration; easing.type: Easing.OutCubic } }

          Rectangle {
            anchors.fill: card
            anchors.margins: -14
            radius: card.radius + 14
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(root.tokens.cyan, 0.22)
            opacity: tile.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.tokens.entryDuration } }
          }

          Rectangle {
            id: card
            antialiasing: true
            anchors.fill: parent
            radius: root.tokens.cardRadius + 4
            color: root.tokens.background
            Common.RoundedClip {
              anchors.fill: parent
              radius: card.radius
              Thumbnail {
                anchors.fill: parent
                service: root.service
                path: tile.modelData.path
                sourceSize.width: 640
              }
              Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                  GradientStop { position: 0.0; color: Qt.alpha(root.tokens.background, 0.12) }
                  GradientStop { position: 0.55; color: "transparent" }
                  GradientStop { position: 1.0; color: Qt.alpha(root.tokens.background, 0.78) }
                }
              }
              Rectangle {
                anchors { left: parent.left; top: parent.top; margins: 10 }
                width: themeText.implicitWidth + 16; height: 22; radius: 6
                color: Qt.alpha(root.tokens.background, 0.82)
                border.width: 1
                border.color: Qt.alpha(root.tokens.text, 0.10)
                Text {
                  id: themeText
                  anchors.centerIn: parent
                  text: tile.modelData.theme === "light" ? "LIGHT" : tile.modelData.theme === "dark" ? "DARK" : "SHARED"
                  color: root.tokens.muted
                  font.family: root.tokens.font
                  font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                }
              }
              Rectangle {
                visible: tile.inUse || tile.kind === "video" || tile.kind === "gif"
                anchors { right: parent.right; top: parent.top; margins: 10 }
                width: statusText.implicitWidth + 16; height: 22; radius: 6
                color: tile.inUse ? Qt.alpha(root.tokens.cyan, 0.16) : Qt.alpha(root.tokens.background, 0.82)
                border.width: 1
                border.color: tile.inUse ? Qt.alpha(root.tokens.cyan, 0.45) : Qt.alpha(root.tokens.text, 0.10)
                Text {
                  id: statusText
                  anchors.centerIn: parent
                  text: tile.inUse ? "● IN USE" : tile.kind === "video" ? "VIDEO" : "GIF"
                  color: tile.inUse ? root.tokens.cyan : root.tokens.muted
                  font.family: root.tokens.font
                  font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
                }
              }
            }
            Rectangle {
              anchors.fill: parent
              radius: card.radius
              color: "transparent"
              antialiasing: true
              border.width: tile.selected ? 2 : 1
              border.color: tile.selected ? root.tokens.cyan : root.tokens.border
            }
          }
          HoverHandler { id: cardHover }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentIndex = tile.index; root.center(); }
            onDoubleClicked: root.applyCurrent()
            Accessible.role: Accessible.Button
            Accessible.name: tile.modelData.name
            Accessible.onPressAction: { root.currentIndex = tile.index; root.applyCurrent(); }
          }
        }
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.leftMargin: 22
      anchors.verticalCenter: parent.verticalCenter
      width: 46; height: 46; radius: 23
      z: 200
      color: prevHover.hovered ? Qt.alpha(root.tokens.surface, 0.92) : Qt.alpha(root.tokens.surface, 0.55)
      border.width: 1
      border.color: prevHover.hovered ? Qt.alpha(root.tokens.cyan, 0.5) : root.tokens.border
      opacity: root.items.length > 1 ? 1 : 0.18
      enabled: root.items.length > 1
      Behavior on opacity { NumberAnimation { duration: root.tokens.entryDuration } }
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
      Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        text: "‹"
        color: root.tokens.text
        font.family: root.tokens.font
        font.pixelSize: 26
      }
      HoverHandler { id: prevHover }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.move(-1)
        Accessible.role: Accessible.Button
        Accessible.name: "Previous wallpaper"
      }
    }
    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: 22
      anchors.verticalCenter: parent.verticalCenter
      width: 46; height: 46; radius: 23
      z: 200
      color: nextHover.hovered ? Qt.alpha(root.tokens.surface, 0.92) : Qt.alpha(root.tokens.surface, 0.55)
      border.width: 1
      border.color: nextHover.hovered ? Qt.alpha(root.tokens.cyan, 0.5) : root.tokens.border
      opacity: root.items.length > 1 ? 1 : 0.18
      enabled: root.items.length > 1
      Behavior on opacity { NumberAnimation { duration: root.tokens.entryDuration } }
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
      Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        text: "›"
        color: root.tokens.text
        font.family: root.tokens.font
        font.pixelSize: 26
      }
      HoverHandler { id: nextHover }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.move(1)
        Accessible.role: Accessible.Button
        Accessible.name: "Next wallpaper"
      }
    }

    WheelHandler {
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => {
        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
        if (delta !== 0) root.move(delta > 0 ? -1 : 1);
      }
    }

    Column {
      anchors.centerIn: parent
      width: parent.width - 80
      spacing: 10
      visible: !root.items.length
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 62; height: 62; radius: 18
        color: Qt.alpha(root.tokens.surface, 0.55)
        border.width: 1
        border.color: root.tokens.border
        Rectangle {
          anchors.centerIn: parent
          width: 28; height: 20; radius: 3
          color: "transparent"
          border.width: 1
          border.color: root.tokens.muted
          Rectangle {
            width: 6; height: 6; radius: 3
            color: root.tokens.muted
            anchors { right: parent.right; top: parent.top; margins: 3 }
          }
        }
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.service.scanning ? "Scanning your library…" : "No wallpapers here"
        color: root.tokens.text
        font.family: root.tokens.font
        font.pixelSize: 22
        font.bold: true
        wrapMode: Text.Wrap
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: !root.service.scanning
        text: "Open the full selector to choose another folder."
        color: root.tokens.muted
        font.family: root.tokens.font
        font.pixelSize: 12
        wrapMode: Text.Wrap
      }
    }
  }

  Item {
    id: footer
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 30; rightMargin: 30; bottomMargin: 22 }
    height: 118
    opacity: root.items.length ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: root.tokens.entryDuration } }

    Rectangle {
      id: panel
      anchors { left: parent.left; right: parent.right; top: parent.top }
      height: 88
      radius: root.tokens.panelRadius
      color: Qt.alpha(root.tokens.surface, 0.84)
      border.width: 1
      border.color: Qt.alpha(root.tokens.text, 0.07)
      Item {
        anchors.fill: parent
        anchors.margins: 14
        Item {
          id: counter
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 118
          Text {
            id: numberText
            text: root.currentIndex >= 0 ? root.pad(root.currentIndex + 1) : "00"
            color: root.tokens.cyan
            font.family: root.tokens.mono
            font.pixelSize: 30
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -5
          }
          Text {
            anchors { left: numberText.right; leftMargin: 3; baseline: numberText.baseline }
            text: "/ " + root.items.length
            color: root.tokens.muted
            font.family: root.tokens.mono
            font.pixelSize: 12
          }
          Text {
            anchors { left: parent.left; bottom: parent.bottom }
            text: "POSITION"
            color: root.tokens.muted
            font.family: root.tokens.font
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 2
          }
        }
        Rectangle {
          anchors {
            left: counter.right
            top: parent.top; bottom: parent.bottom
            topMargin: 4; bottomMargin: 4
          }
          width: 1
          color: root.tokens.border
        }
        Item {
          id: info
          anchors {
            left: counter.right; leftMargin: 24
            right: actions.left; rightMargin: 24
            top: parent.top; bottom: parent.bottom
          }
          Text {
            id: title
            anchors { left: parent.left; right: parent.right; top: parent.top }
            text: root.current ? root.current.name : "No wallpaper selected"
            textFormat: Text.PlainText
            color: root.tokens.text
            font.family: root.tokens.font
            font.pixelSize: 19
            font.bold: true
            elide: Text.ElideMiddle
          }
          Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            spacing: 8
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.current && root.current.kind ? root.current.kind.toUpperCase() : "IMAGE"
              color: root.tokens.muted
              font.family: root.tokens.font
              font.pixelSize: 9
              font.bold: true
              font.letterSpacing: 1.5
            }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 3; height: 3; radius: 1.5
              color: root.tokens.muted
              opacity: 0.5
            }
            Text {
              width: Math.max(0, parent.width - 82)
              anchors.verticalCenter: parent.verticalCenter
              text: root.current ? (root.current.relative || root.current.path) : ""
              color: root.tokens.muted
              font.family: root.tokens.mono
              font.pixelSize: 10
              elide: Text.ElideMiddle
            }
          }
        }
        Row {
          id: actions
          anchors { right: parent.right; verticalCenter: parent.verticalCenter }
          spacing: 10
          WallpaperButton {
            tokens: root.tokens
            text: "Apply  ↵"
            highlighted: true
            implicitHeight: 42
            font.pixelSize: 13
            font.bold: true
            enabled: root.items.length > 0 && !root.service.scanning && !root.service.transaction && !root.service.blocked
            onClicked: root.applyCurrent()
            Accessible.name: "Apply selected wallpaper"
          }
        }
      }
    }

    Row {
      anchors { top: panel.bottom; topMargin: 12; horizontalCenter: parent.horizontalCenter }
      spacing: 20
      Repeater {
        model: [
          {key: "← →", label: "Navigate"},
          {key: "↵", label: "Apply"},
          {key: "Esc", label: "Close"}
        ]
        delegate: Row {
          required property var modelData
          spacing: 6
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(22, keyText.implicitWidth + 12)
            height: 18
            radius: 5
            color: Qt.alpha(root.tokens.surface, 0.7)
            border.width: 1
            border.color: root.tokens.border
            Text {
              id: keyText
              anchors.centerIn: parent
              text: modelData.key
              color: root.tokens.text
              font.family: root.tokens.mono
              font.pixelSize: 9
              font.bold: true
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            color: root.tokens.muted
            font.family: root.tokens.font
            font.pixelSize: 10
          }
        }
      }
    }
  }
}
