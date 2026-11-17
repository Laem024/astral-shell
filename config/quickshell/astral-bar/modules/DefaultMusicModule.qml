pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../../common" as Design
import "../data" as Data

Item {
  id: root
  objectName: "music"
  required property Design.Theme tokens
  property var media: Data.MediaData
  property bool vertical: false
  property bool compact: false
  readonly property bool hovered: hover.hovered
  readonly property color ink: hovered ? tokens.cyan : tokens.lavender
  signal activated()
  implicitWidth: vertical ? 48 : compact ? 124 : 340
  implicitHeight: vertical ? 134 : 42
  HoverHandler { id: hover }

  component Transport: Button {
    id: control
    required property string kind
    required property string label
    property bool primary: false
    objectName: "barMedia-" + kind
    implicitWidth: primary ? 28 : 26
    implicitHeight: 28
    padding: 0
    focusPolicy: Qt.StrongFocus
    Accessible.name: label
    opacity: enabled ? 1 : 0.3
    background: Rectangle {
      radius: height / 2
      color: "transparent"
      border.color: control.visualFocus ? root.tokens.gold : "transparent"
      border.width: control.visualFocus ? 1 : 0
      scale: control.down ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: root.tokens.hoverDuration } }
    }
    contentItem: Item {
      id: iconContent
      property color ink: control.primary || control.hovered ? root.tokens.cyan : root.tokens.muted
      Behavior on ink { ColorAnimation { duration: root.tokens.hoverDuration } }
      Item {
        anchors.centerIn: parent
        width: 16; height: 16
        rotation: control.kind === "previous" ? 180 : 0
        Shape {
          anchors.fill: parent
          visible: control.kind !== "pause"
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: "transparent"
            fillColor: iconContent.ink
            startX: 4; startY: 3
            PathLine { x: 12; y: 8 }
            PathLine { x: 4; y: 13 }
            PathLine { x: 4; y: 3 }
          }
        }
        Rectangle {
          visible: control.kind === "previous" || control.kind === "next"
          x: 12; y: 3; width: 2; height: 10; radius: 0.5
          color: iconContent.ink
        }
        Rectangle {
          visible: control.kind === "pause"
          x: 3; y: 3; width: 3; height: 10; radius: 0.7
          color: iconContent.ink
        }
        Rectangle {
          visible: control.kind === "pause"
          x: 10; y: 3; width: 3; height: 10; radius: 0.7
          color: iconContent.ink
        }
      }
    }



  }

  GridLayout {
    anchors.fill: parent
    anchors.leftMargin: root.vertical ? 7 : 8
    anchors.rightMargin: root.vertical ? 7 : 0
    anchors.topMargin: 2
    anchors.bottomMargin: 2
    columns: root.vertical ? 1 : 4
    columnSpacing: 2
    rowSpacing: 3
    Button {
      id: information
      Layout.fillWidth: true
      Layout.fillHeight: !root.vertical
      Layout.preferredHeight: root.vertical || root.compact ? 30 : 36
      Layout.minimumWidth: 30
      Layout.rightMargin: root.vertical || root.compact ? 0 : root.tokens.gap
      padding: 0
      focusPolicy: Qt.StrongFocus
      Accessible.name: root.media.title + " · " + root.media.artist + ". Open Music"
      onClicked: root.activated()
      background: Rectangle {
        radius: root.tokens.rowRadius
        color: "transparent"
        border.color: information.visualFocus ? root.tokens.gold : "transparent"
      }
      contentItem: RowLayout {
        spacing: 10
        Rectangle {
          id: sleeve
          Layout.preferredWidth: root.vertical || root.compact ? 28 : 32
          Layout.preferredHeight: Layout.preferredWidth
          Layout.alignment: Qt.AlignCenter
          radius: 8
          color: "transparent"
          clip: true
          Item {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            width: 25; height: 25
            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: Qt.alpha(root.tokens.cyan, 0.06)
              border.color: Qt.alpha(root.tokens.cyan, 0.3)
            }
            Rectangle {
              anchors.centerIn: parent
              width: 15; height: 15; radius: 7.5
              color: "transparent"
              border.color: Qt.alpha(root.tokens.cyan, 0.18)
            }
            Rectangle {
              anchors.centerIn: parent
              width: 5; height: 5; radius: 2.5
              color: root.media.playing ? root.tokens.cyan : root.tokens.gold
            }
            Rectangle { x: 18; y: 3; width: 1; height: 14; rotation: 24; color: root.tokens.lavender }
          }
          Image {
            id: cover
            anchors.fill: parent
            source: root.media.artwork
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }
          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 2
            visible: (root.vertical || root.compact) && root.media.length > 0
            color: Qt.alpha(root.tokens.muted, 0.2)
            Rectangle { width: parent.width * root.media.progress; height: 2; color: root.tokens.cyan }
          }
        }
        ColumnLayout {
          visible: !root.vertical && !root.compact
          Layout.fillWidth: true
          spacing: 3
          Text {
            Layout.fillWidth: true
            text: root.media.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: information.hovered ? root.tokens.cyan : root.tokens.text
            font { family: root.tokens.font; pixelSize: root.tokens.textSize + 1; weight: Font.Medium }
          }
          Text {
            Layout.fillWidth: true
            objectName: "barMediaArtist"
            text: root.media.artist
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.tokens.lavender
            font { family: root.tokens.font; pixelSize: 11 }
          }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            visible: root.media.length > 0
            color: Qt.alpha(root.tokens.muted, 0.14)
            Rectangle { width: parent.width * root.media.progress; height: 1; color: root.ink }
          }
        }
      }



    }
    Transport {
      Layout.alignment: Qt.AlignCenter
      kind: "previous"; label: "Previous track"
      enabled: root.media.canPrevious
      onClicked: root.media.previous()
    }
    Transport {
      Layout.alignment: Qt.AlignCenter
      kind: root.media.playing ? "pause" : "play"
      label: root.media.playing ? "Pause" : "Play"
      primary: true
      enabled: root.media.canToggle
      onClicked: root.media.toggle()
    }
    Transport {
      Layout.alignment: Qt.AlignCenter
      kind: "next"; label: "Next track"
      enabled: root.media.canNext
      onClicked: root.media.next()
    }
  }
}
