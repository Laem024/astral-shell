pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../../common" as Design
import "../data" as Data
import "../components" as Components

// Device controls first, followed by per-application streams.
ScrollView {
  id: root
  required property Design.Theme tokens
  contentWidth: availableWidth
  clip: true
  // Curve-rendered sigils need a layer to respect the scrolling viewport.
  layer.enabled: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

  readonly property var sinkDevices: Data.AudioData.outputs
  readonly property var sourceDevices: Data.AudioData.inputs
  readonly property int streamCount: Data.AudioData.playback.length

  component Eyebrow: Text {
    property color tone: root.tokens.muted
    Layout.fillWidth: true
    textFormat: Text.PlainText
    color: tone
    elide: Text.ElideRight
    font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1 }
  }
  component Caption: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    color: root.tokens.muted
    font { family: root.tokens.font; pixelSize: 11 }
  }
  component Section: PanelCard {
    tokens: root.tokens
    contentSpacing: 14
  }
  // Square icon tile shared by every card header and stream row.
  component IconTile: Rectangle {
    id: tile
    required property color accent
    property string kind: "speaker"
    property bool muted: false
    property real level: 1
    property int size: 32
    Layout.preferredWidth: size
    Layout.preferredHeight: size
    Layout.alignment: Qt.AlignTop
    radius: root.tokens.rowRadius
    color: Qt.alpha(tile.accent, 0.1)
    border.width: 1
    border.color: Qt.alpha(tile.accent, 0.25)
    Components.SoundGlyph {
      anchors.centerIn: parent
      kind: tile.kind
      muted: tile.muted
      level: tile.level
      ink: tile.accent
    }
  }
  // Short chevron used by the device selector; flips while the popup is open.
  component Chevron: Shape {
    id: chevron
    property bool open: false
    property color ink: root.tokens.muted
    width: 12
    height: 12
    preferredRendererType: Shape.CurveRenderer
    rotation: open ? 180 : 0
    Behavior on rotation { NumberAnimation { duration: root.tokens.hoverDuration } }
    Accessible.ignored: true
    ShapePath {
      strokeColor: chevron.ink
      strokeWidth: 1.4
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M1.5 4 L6 8.5 L10.5 4" }
    }
  }
  component DeviceCard: Section {
    id: card
    required property bool output
    readonly property var devices: output ? root.sinkDevices : root.sourceDevices
    readonly property var current: output ? Data.AudioData.sink : Data.AudioData.source
    readonly property bool ready: Data.AudioData.usable(current)
    accent: output ? root.tokens.cyan : root.tokens.lavender
    RowLayout {
      Layout.fillWidth: true
      spacing: 12
      IconTile {
        accent: card.ready ? card.accent : root.tokens.muted
        kind: card.ready ? Data.AudioData.glyph(card.current) : card.output ? "speaker" : "microphone"
        muted: card.ready && card.current.audio.muted
        level: card.ready ? Math.max(0, Data.AudioData.percent(card.current)) / 100 : 0
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        Eyebrow { text: card.output ? "OUTPUT" : "MICROPHONE"; tone: card.ready ? card.accent : root.tokens.muted }
        Caption {
          visible: !card.ready
          text: "Waiting for PipeWire to expose this device"
          font.pixelSize: 10
        }
      }
    }
    VolumeControl {
      tokens: root.tokens
      node: card.current
      label: card.output ? "Output" : "Microphone"
      accent: card.accent
    }
    ComboBox {
      id: selector
      Layout.fillWidth: true
      implicitHeight: 36
      leftPadding: 12; rightPadding: 34
      hoverEnabled: true
      enabled: Data.AudioData.available && card.devices.length > 0
      model: card.devices.map(node => Data.AudioData.label(node))
      currentIndex: card.devices.indexOf(card.current)
      displayText: currentIndex >= 0 ? currentText : card.output ? "No output device" : "No input device"
      Accessible.name: card.output ? "Default output device" : "Default input device"
      onActivated: index => {
        if (card.output) Data.AudioData.selectOutput(card.devices[index]);
        else Data.AudioData.selectInput(card.devices[index]);
      }
      contentItem: Text {
        text: selector.displayText
        textFormat: Text.PlainText
        font { family: root.tokens.font; pixelSize: 12 }
        color: selector.enabled ? root.tokens.text : root.tokens.muted
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }
      indicator: Chevron {
        x: selector.width - width - 12
        anchors.verticalCenter: parent.verticalCenter
        open: selector.popup.visible
        ink: selector.popup.visible ? card.accent : root.tokens.muted
      }
      background: Rectangle {
        radius: root.tokens.rowRadius
        color: selector.hovered || selector.popup.visible ? root.tokens.raised : root.tokens.sunken
        border.width: 1
        border.color: selector.activeFocus || selector.popup.visible ? Qt.alpha(card.accent, 0.6) : root.tokens.border
      }
      delegate: ItemDelegate {
        id: option
        required property int index
        required property string modelData
        width: selector.width - 8
        implicitHeight: 36
        leftPadding: 8; rightPadding: 8
        highlighted: selector.highlightedIndex === index
        Accessible.name: option.modelData
        contentItem: RowLayout {
          spacing: 8
          Components.SoundGlyph {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            kind: card.devices[option.index] ? Data.AudioData.glyph(card.devices[option.index]) : ""
            ink: option.index === selector.currentIndex ? card.accent : root.tokens.muted
          }
          Text {
            Layout.fillWidth: true
            text: option.modelData
            textFormat: Text.PlainText
            color: option.index === selector.currentIndex ? card.accent : root.tokens.text
            font { family: root.tokens.font; pixelSize: 12 }
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
          }
        }
        background: Rectangle {
          radius: root.tokens.rowRadius - 2
          color: option.highlighted ? Qt.alpha(card.accent, 0.1) : "transparent"
        }
      }
      popup: Popup {
        y: selector.height + 4
        width: selector.width
        padding: 4
        implicitHeight: Math.min(210, deviceList.contentHeight + 8)
        contentItem: ListView {
          id: deviceList
          clip: true
          implicitHeight: contentHeight
          model: selector.popup.visible ? selector.delegateModel : null
          currentIndex: selector.highlightedIndex
          ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle {
          radius: root.tokens.rowRadius
          color: root.tokens.surface
          border.color: Qt.alpha(card.accent, 0.24)
        }
      }
    }
    Caption {
      visible: !card.ready
      text: "Connect a device to make it available here."
      font.pixelSize: 10
    }
  }

  ColumnLayout {
    width: root.availableWidth
    spacing: 12
    PageIntro {
      tokens: root.tokens
      title: "Your sound, fine-tuned"
      subtitle: root.sinkDevices.length + " outputs · " + root.sourceDevices.length + " inputs · " + root.streamCount + " audio streams"
      symbol: "sound"
      accent: root.tokens.cyan
    }
    Rectangle {
      Layout.fillWidth: true
      visible: !Data.AudioData.available
      implicitHeight: unavailableRow.implicitHeight + 24
      radius: root.tokens.rowRadius
      color: Qt.alpha(root.tokens.alert, 0.1)
      border.color: Qt.alpha(root.tokens.alert, 0.35)
      RowLayout {
        id: unavailableRow
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 10
        Components.SoundGlyph {
          Layout.alignment: Qt.AlignTop
          kind: "speaker"
          muted: true
          level: 0
          ink: root.tokens.alert
        }
        Text {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          text: "Audio unavailable. Waiting for PipeWire…"
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: root.tokens.alert
          font { family: root.tokens.font; pixelSize: 11 }
        }
      }
    }
    GridLayout {
      Layout.fillWidth: true
      columns: root.availableWidth >= 460 ? 2 : 1
      columnSpacing: 12; rowSpacing: 12
      DeviceCard { objectName: "audioOutputCard"; output: true; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop }
      DeviceCard { objectName: "audioInputCard"; output: false; Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop }
    }
    Section {
      objectName: "audioMixerCard"
      accent: root.tokens.gold
      RowLayout {
        Layout.fillWidth: true
        spacing: 12
        IconTile {
          accent: root.tokens.gold
          kind: "mixer"
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 2
          Eyebrow { text: "APPLICATIONS"; tone: root.tokens.gold }
          Text {
            Layout.fillWidth: true
            text: "Application mixer"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.tokens.text
            font { family: root.tokens.font; pixelSize: 14; weight: Font.Medium }
          }
          Caption {
            text: root.streamCount === 0 ? "Play audio in an app to control its volume here."
              : "Each application keeps its own volume and mute state."
            font.pixelSize: 10
          }
        }
      }
      Repeater {
        model: Data.AudioData.playback
        Rectangle {
          id: stream
          required property var modelData
          readonly property string appLabel: Data.AudioData.appName(modelData)
          Layout.fillWidth: true
          implicitHeight: streamRow.implicitHeight + 24
          radius: root.tokens.rowRadius
          color: root.tokens.sunken
          border.width: 1
          border.color: root.tokens.hairline
          RowLayout {
            id: streamRow
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
            spacing: 12
            IconTile {
              size: 32
              accent: root.tokens.gold
              kind: "stream"
              muted: Data.AudioData.usable(stream.modelData) && stream.modelData.audio.muted
              level: Math.max(0, Data.AudioData.percent(stream.modelData)) / 100
            }
            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 4
              Text {
                Layout.fillWidth: true
                text: stream.appLabel
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.tokens.text
                font { family: root.tokens.font; pixelSize: 13; weight: Font.Medium }
              }
              VolumeControl {
                tokens: root.tokens
                node: stream.modelData
                label: stream.appLabel
                accent: root.tokens.gold
              }
            }
          }
        }
      }
    }
  }
}
