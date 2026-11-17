pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data
import "../components" as Components

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
  implicitWidth: vertical ? 48 : compact ? 148 : 340
  implicitHeight: vertical ? 134 : 46
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
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: label
    opacity: enabled ? 1 : 0.3
    background: Components.BarTile {
      tokens: root.tokens
      radius: 9
      hovered: control.hovered
      selected: control.down
      tinted: control.primary
      focused: control.visualFocus
      scale: control.down ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: root.tokens.hoverDuration } }
    }
    contentItem: Item {
      id: iconContent
      property color ink: control.primary || control.hovered ? root.tokens.cyan : root.tokens.muted
      Behavior on ink { ColorAnimation { duration: root.tokens.hoverDuration } }
      Components.BarGlyph {
        anchors.centerIn: parent
        width: 17; height: 17
        kind: control.kind
        ink: iconContent.ink
      }
    }
  }

  GridLayout {
    anchors.fill: parent
    anchors.leftMargin: root.vertical ? 7 : 8
    anchors.rightMargin: root.vertical ? 7 : 4
    anchors.topMargin: 2
    anchors.bottomMargin: 2
    columns: root.vertical ? 1 : 4
    columnSpacing: 2
    rowSpacing: 3
    Button {
      id: information
      objectName: "barMediaInformation"
      Layout.fillWidth: true
      Layout.fillHeight: !root.vertical
      Layout.preferredHeight: root.vertical ? 34 : 40
      Layout.minimumWidth: root.vertical ? 34 : 40
      Layout.rightMargin: root.vertical ? 0 : root.tokens.gap
      padding: 3
      horizontalPadding: root.vertical ? 3 : 6
      focusPolicy: Qt.StrongFocus
      Accessible.name: root.media.title + " · " + root.media.artist + ". Open Music"
      onClicked: root.activated()
      background: Components.BarTile {
        tokens: root.tokens
        hovered: information.hovered
        focused: information.visualFocus
      }
      contentItem: RowLayout {
        spacing: 10
        Components.RoundedClip {
          id: sleeve
          objectName: "barMediaArtwork"
          Layout.minimumWidth: Layout.preferredWidth
          Layout.maximumWidth: Layout.preferredWidth
          Layout.preferredWidth: root.vertical || root.compact ? 28 : 32
          Layout.preferredHeight: Layout.preferredWidth
          Layout.alignment: Qt.AlignCenter
          radius: 8
          Rectangle {
            anchors.fill: parent
            visible: cover.status !== Image.Ready
            radius: 8
            color: Qt.alpha(root.tokens.lavender, 0.1)
            Components.BarGlyph {
              anchors.centerIn: parent
              width: 20; height: 20
              kind: "music"
              ink: root.media.playing ? root.tokens.cyan : root.tokens.lavender
            }
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
            color: root.tokens.muted
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
