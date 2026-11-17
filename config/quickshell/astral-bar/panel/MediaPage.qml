pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import "../data" as Data
import "../components" as Components
import "../../common" as Design

Item {
  id: root
  required property Design.Theme tokens
  property var media: Data.MediaData
  readonly property var player: media.player
  readonly property real progress: media.progress
  readonly property bool largeArtwork: height >= 440
  readonly property int inset: height < 400 ? 12 : 16
  function duration(seconds: real): string {
    const value = Math.max(0, Math.floor(seconds));
    return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0");
  }
  clip: true
  // Curve-rendered icons need a layer to respect the scrolling viewport clip.
  layer.enabled: true

  component Transport: Button {
    id: control
    objectName: "mediaTransport-" + kind
    required property string kind
    required property string label
    property bool primary: false
    property bool active: false
    implicitWidth: primary ? 56 : 32
    implicitHeight: primary ? 56 : 32
    padding: 0
    focusPolicy: Qt.StrongFocus
    Accessible.name: label
    opacity: enabled ? 1 : 0.3
    background: Rectangle {
      radius: width / 2
      color: control.primary ? root.tokens.cyan
        : control.active || control.hovered ? Qt.alpha(root.tokens.cyan, 0.1) : "transparent"
      border.color: control.visualFocus ? root.tokens.gold : "transparent"
      border.width: control.visualFocus ? 2 : 0
      scale: control.down ? 0.94 : 1
      Behavior on scale { NumberAnimation { duration: root.tokens.hoverDuration } }
    }
    Item {
      anchors.centerIn: parent
      width: 20; height: 20
      readonly property color ink: control.primary ? root.tokens.background : control.active ? root.tokens.cyan : root.tokens.muted
      Rectangle {
        visible: control.kind === "pause"
        x: 4; y: 3; width: 4; height: 14; radius: 1
        color: parent.ink
      }
      Rectangle {
        visible: control.kind === "pause"
        x: 12; y: 3; width: 4; height: 14; radius: 1
        color: parent.ink
      }
      Shape {
        visible: control.kind === "previous" || control.kind === "next" || control.kind === "play"
        anchors.fill: parent
        rotation: control.kind === "previous" ? 180 : 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: "transparent"
          fillColor: control.primary ? root.tokens.background : root.tokens.text
          startX: 5; startY: 3
          PathLine { x: 15; y: 10 }
          PathLine { x: 5; y: 17 }
          PathLine { x: 5; y: 3 }
        }
        ShapePath {
          strokeColor: "transparent"
          fillColor: control.kind === "play" ? "transparent" : root.tokens.text
          startX: 16; startY: 3
          PathLine { x: 18; y: 3 }
          PathLine { x: 18; y: 17 }
          PathLine { x: 16; y: 17 }
          PathLine { x: 16; y: 3 }
        }
      }
      Shape {
        visible: control.kind === "shuffle"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: "transparent"
          strokeColor: control.active ? root.tokens.cyan : root.tokens.muted
          strokeWidth: 1.5
          startX: 2; startY: 5
          PathLine { x: 6; y: 5 }
          PathLine { x: 14; y: 15 }
          PathLine { x: 18; y: 15 }
          PathMove { x: 2; y: 15 }
          PathLine { x: 6; y: 15 }
          PathLine { x: 14; y: 5 }
          PathLine { x: 18; y: 5 }
          PathMove { x: 15; y: 2 }
          PathLine { x: 18; y: 5 }
          PathLine { x: 15; y: 8 }
          PathMove { x: 15; y: 12 }
          PathLine { x: 18; y: 15 }
          PathLine { x: 15; y: 18 }
        }
      }
      Shape {
        visible: control.kind === "repeat"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: "transparent"
          strokeColor: control.active ? root.tokens.cyan : root.tokens.muted
          strokeWidth: 1.5
          startX: 3; startY: 9
          PathLine { x: 3; y: 5 }
          PathLine { x: 17; y: 5 }
          PathLine { x: 14; y: 2 }
          PathMove { x: 17; y: 5 }
          PathLine { x: 14; y: 8 }
          PathMove { x: 17; y: 11 }
          PathLine { x: 17; y: 15 }
          PathLine { x: 3; y: 15 }
          PathLine { x: 6; y: 18 }
          PathMove { x: 3; y: 15 }
          PathLine { x: 6; y: 12 }
        }
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: root.tokens.cardRadius
    color: root.tokens.raised
    border.color: root.tokens.border
  }
  Components.RoundedClip {
    anchors.fill: parent
    radius: root.tokens.cardRadius
    Flickable {
      id: scroll
      objectName: "mediaViewport"
      anchors.fill: parent
      contentWidth: width
      contentHeight: Math.max(height, composition.implicitHeight + root.inset * 2)
      interactive: contentHeight > height
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      ScrollBar.vertical: ScrollBar {}
      ColumnLayout {
        id: composition
        x: root.inset; y: root.inset
        width: Math.max(0, root.width - root.inset * 2)
        height: Math.max(implicitHeight, scroll.height - root.inset * 2)
        spacing: root.height >= 460 ? 16 : root.largeArtwork ? 12 : 8
        ComboBox {
          id: selector
          objectName: "mediaPlayerSelector"
          Layout.fillWidth: true
          implicitHeight: 36
          leftPadding: 12; rightPadding: 34
          Accessible.name: "Media player"
          model: [{name: "Automatic", key: ""}].concat(root.media.playerOptions)
          textRole: "name"
          currentIndex: Math.max(0, model.findIndex(row => row.key === root.media.manualName))
          onActivated: index => root.media.select(model[index].key)
          background: Rectangle {
            radius: root.tokens.rowRadius
            color: selector.hovered || selector.popup.visible ? Qt.alpha(root.tokens.text, 0.08) : root.tokens.background
            border.width: selector.visualFocus ? 2 : 1
            border.color: selector.visualFocus ? root.tokens.cyan
              : Qt.alpha(root.tokens.cyan, selector.popup.visible ? 0.4 : 0.2)
          }
          contentItem: RowLayout {
            spacing: 12
            Text {
              text: "PLAYER"
              color: root.tokens.muted
              font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 1 }
            }
            Text {
              Layout.fillWidth: true
              text: root.media.automatic && root.player ? "Auto · " + root.media.application : selector.displayText
              textFormat: Text.PlainText
              color: root.tokens.cyan
              horizontalAlignment: Text.AlignRight
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
              font { family: root.tokens.font; pixelSize: 11; weight: Font.Medium }
            }
          }
          indicator: Item {
            x: selector.width - width - 12
            y: (selector.height - height) / 2
            width: 10; height: 10
            rotation: selector.popup.visible ? 180 : 0
            Rectangle { x: 1; y: 4; width: 6; height: 1.5; radius: 0.75; rotation: 45; color: root.tokens.cyan }
            Rectangle { x: 5; y: 4; width: 6; height: 1.5; radius: 0.75; rotation: -45; color: root.tokens.cyan }
          }
          delegate: ItemDelegate {
            id: playerOption
            required property var modelData
            required property int index
            readonly property bool selected: modelData.key === root.media.manualName
            width: selector.width - 12
            height: 38
            leftPadding: 10; rightPadding: 10
            highlighted: selector.highlightedIndex === index
            Accessible.name: modelData.name
            background: Rectangle {
              radius: 6
              color: Qt.alpha(root.tokens.cyan, playerOption.highlighted ? 0.12 : playerOption.selected ? 0.065 : 0)
              border.color: playerOption.visualFocus ? root.tokens.gold : "transparent"
            }
            contentItem: RowLayout {
              spacing: 10
              Text {
                Layout.fillWidth: true
                text: playerOption.modelData.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: playerOption.selected ? root.tokens.cyan : root.tokens.text
                font { family: root.tokens.font; pixelSize: 11 }
              }
              Rectangle {
                Layout.preferredWidth: 5; Layout.preferredHeight: 5
                radius: 2.5
                color: playerOption.selected ? root.tokens.cyan : "transparent"
              }
            }
          }
          popup: Popup {
            y: selector.height + 6
            width: selector.width
            padding: 6
            implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
            background: Rectangle {
              radius: 10
              color: root.tokens.surface
              border.color: Qt.alpha(root.tokens.cyan, 0.2)
            }
            contentItem: ListView {
              implicitHeight: Math.min(contentHeight, 210)
              model: selector.popup.visible ? selector.delegateModel : null
              currentIndex: selector.highlightedIndex
              clip: true
              spacing: 3
              boundsBehavior: Flickable.StopAtBounds
              ScrollBar.vertical: ScrollBar {}
            }
          }
        }
        GridLayout {
          id: hero
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: implicitHeight
          columns: root.largeArtwork ? 1 : 2
          columnSpacing: 16
          rowSpacing: 16
          Item {
            id: sleeve
            objectName: "mediaArtworkFrame"
            Layout.alignment: Qt.AlignHCenter
            readonly property real aspect: artwork.status === Image.Ready && artwork.implicitHeight > 0
              ? Math.max(0.5, Math.min(1.8, artwork.implicitWidth / artwork.implicitHeight)) : 1
            Layout.preferredHeight: root.largeArtwork
              ? Math.floor(Math.min(composition.width - 20, Math.max(64, scroll.height - root.inset * 2
                  - selector.implicitHeight - trackInfo.implicitHeight - timeline.implicitHeight
                  - transportRow.implicitHeight - repeatMode.implicitHeight
                  - composition.spacing * 4 - hero.rowSpacing - 1)))
              : Math.min(96, composition.width * 0.4)
            Layout.preferredWidth: Math.min(composition.width, Layout.preferredHeight * aspect)
            Accessible.role: Accessible.Graphic
            Accessible.name: root.player ? "Artwork for " + root.media.title : "No track artwork"
            Components.RoundedClip {
              anchors.fill: parent
              radius: 16
              Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                  GradientStop { position: 0; color: Qt.tint(root.tokens.surface, Qt.alpha(root.tokens.cyan, 0.09)) }
                  GradientStop { position: 1; color: root.tokens.background }
                }
              }
              Item {
                id: fallback
                objectName: "mediaArtworkFallback"
                anchors.centerIn: parent
                width: parent.width * 0.78; height: width
                visible: artwork.status !== Image.Ready
                Repeater {
                  model: 5
                  Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width * (1 - index * 0.15); height: width
                    radius: width / 2
                    color: index === 4 ? Qt.alpha(root.tokens.cyan, 0.12) : "transparent"
                    border.color: Qt.alpha(root.tokens.cyan, 0.14 + index * 0.025)
                  }
                }
                Rectangle {
                  anchors.centerIn: parent
                  width: Math.max(5, parent.width * 0.065); height: width; radius: width / 2
                  color: root.tokens.gold
                }
                Rectangle {
                  x: parent.width * 0.8; y: parent.height * 0.08
                  width: 2; height: parent.height * 0.53
                  rotation: 23; radius: 1
                  color: root.tokens.lavender
                }
              }
              Image {
                id: artwork
                objectName: "mediaArtwork"
                anchors.fill: parent
                source: root.media.artwork
                sourceSize.width: Math.ceil(1024 * root.tokens.scale)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
              }
            }
            Rectangle {
              anchors.fill: parent
              radius: 16
              color: "transparent"
              border.color: Qt.alpha(root.tokens.cyan, 0.18)
            }
          }
          ColumnLayout {
            id: trackInfo
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 6
            Text {
              Layout.fillWidth: true
              text: root.media.title
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
              horizontalAlignment: root.largeArtwork ? Text.AlignHCenter : Text.AlignLeft
              color: root.tokens.text
              font { family: root.tokens.font; pixelSize: root.largeArtwork ? 24 : 20; weight: Font.DemiBold }
            }
            Text {
              Layout.fillWidth: true
              text: root.player ? root.media.artist : "Open a media app to begin"
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
              horizontalAlignment: root.largeArtwork ? Text.AlignHCenter : Text.AlignLeft
              color: root.tokens.cyan
              font { family: root.tokens.font; pixelSize: 12 }
            }
            Text {
              Layout.fillWidth: true
              visible: text !== ""
              text: root.media.album
              textFormat: Text.PlainText
              elide: Text.ElideRight
              horizontalAlignment: root.largeArtwork ? Text.AlignHCenter : Text.AlignLeft
              color: root.tokens.muted
              font { family: root.tokens.font; pixelSize: 10 }
            }
          }
        }
        ColumnLayout {
          id: timeline
          Layout.fillWidth: true
          spacing: 0
          Slider {
            id: seek
            objectName: "mediaSeek"
            Layout.fillWidth: true
            implicitHeight: 28
            leftPadding: 0; rightPadding: 0
            from: 0; to: root.media.length || 1
            value: root.media.position
            enabled: root.media.canSeek
            Accessible.name: "Playback position"
            onMoved: root.media.seek(value)
            background: Rectangle {
              x: seek.leftPadding; y: (seek.height - height) / 2
              width: seek.availableWidth; height: seek.hovered || seek.pressed ? 5 : 3; radius: height / 2
              color: Qt.alpha(root.tokens.muted, 0.13)
              Rectangle { width: parent.width * root.progress; height: parent.height; radius: height / 2; color: root.tokens.cyan }
            }
            handle: Rectangle {
              x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
              y: (seek.height - height) / 2
              width: 10; height: 10; radius: 5
              visible: seek.enabled && (seek.hovered || seek.pressed || seek.visualFocus)
              color: seek.visualFocus ? root.tokens.gold : root.tokens.cyan
            }
          }
          RowLayout {
            Layout.fillWidth: true
            Text { text: root.duration(root.media.position); color: root.tokens.muted; font { family: root.tokens.mono; pixelSize: 9 } }
            Item { Layout.fillWidth: true }
            Text { text: root.media.length > 0 ? root.duration(root.media.length) : "—"; color: root.tokens.muted; font { family: root.tokens.mono; pixelSize: 9 } }
          }
        }
        RowLayout {
          id: transportRow
          Layout.fillWidth: true
          spacing: 0
          Transport { kind: "shuffle"; label: "Shuffle"; active: root.media.shuffle; enabled: root.media.canShuffle; onClicked: root.media.toggleShuffle() }
          Item { Layout.fillWidth: true }
          Transport { kind: "previous"; label: "Previous track"; enabled: root.media.canPrevious; onClicked: root.media.previous() }
          Item { implicitWidth: 8 }
          Transport { kind: root.media.playing ? "pause" : "play"; label: root.media.playing ? "Pause" : "Play"; primary: true; enabled: root.media.canToggle; onClicked: root.media.toggle() }
          Item { implicitWidth: 8 }
          Transport { kind: "next"; label: "Next track"; enabled: root.media.canNext; onClicked: root.media.next() }
          Item { Layout.fillWidth: true }
          Transport { kind: "repeat"; label: "Repeat: " + root.media.repeatMode; active: root.media.repeatMode !== "Off"; enabled: root.media.canRepeat; onClicked: root.media.cycleRepeat() }
        }
        Text {
          id: repeatMode
          objectName: "mediaRepeatMode"
          Layout.fillWidth: true
          text: root.player ? root.media.application + (root.media.repeatMode === "Off" ? "" : " · Repeat " + root.media.repeatMode) : "No player connected"
          horizontalAlignment: Text.AlignHCenter
          color: root.tokens.muted
          font { family: root.tokens.font; pixelSize: 10 }
        }
      }
    }
  }
}
