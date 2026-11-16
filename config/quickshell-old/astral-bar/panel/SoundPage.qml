pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../design" as Design
import "../data" as Data
import "../components" as Components

ScrollView {
  id: root
  required property Design.Theme tokens
  contentWidth: availableWidth
  clip: true
  // Curve-rendered device glyphs need a layer to respect the scrolling viewport.
  layer.enabled: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

  component Caption: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    color: root.tokens.muted
    font { family: root.tokens.font; pixelSize: 11 }
  }
  component Eyebrow: Caption {
    color: root.tokens.cyan
    font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 1.3 }
  }
  component Section: PanelCard {
    tokens: root.tokens
    radius: 10
    contentSpacing: 14
  }
  // A dial-style sigil: the ring is the live level, the glyph names the device.
  component DeviceMark: Item {
    id: mark
    required property var node
    required property bool output
    required property color accent
    readonly property bool ready: Data.AudioData.usable(mark.node)
    readonly property bool muted: mark.ready && mark.node.audio.muted
    readonly property int value: Data.AudioData.percent(mark.node)
    readonly property color tone: !mark.ready ? root.tokens.muted : mark.muted ? root.tokens.alert : mark.accent
    implicitWidth: 48
    implicitHeight: 48
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Qt.alpha(mark.accent, mark.ready && !mark.muted ? 0.07 : 0.03)
      border.color: Qt.alpha(mark.accent, mark.ready ? 0.24 : 0.1)
    }
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.alpha(root.tokens.muted, mark.ready ? 0.2 : 0.1)
        strokeWidth: 1.3
        fillColor: "transparent"
        PathAngleArc {
          centerX: 24; centerY: 24
          radiusX: 21; radiusY: 21
          startAngle: -90; sweepAngle: 360
        }
      }
      ShapePath {
        strokeColor: mark.ready && !mark.muted && mark.value > 0 ? mark.accent : "transparent"
        strokeWidth: 2.2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: 24; centerY: 24
          radiusX: 21; radiusY: 21
          startAngle: -90
          sweepAngle: 360 * Math.min(100, Math.max(0, mark.value)) / 100
        }
      }
    }
    Components.SoundGlyph {
      anchors.centerIn: parent
      kind: mark.ready ? Data.AudioData.glyph(mark.node) : mark.output ? "speaker" : "microphone"
      muted: mark.muted
      level: mark.ready ? Math.max(0, mark.value) / 100 : 0
      ink: mark.tone
    }
  }
  component LevelBadge: Rectangle {
    id: badge
    required property var node
    required property color accent
    readonly property int value: Data.AudioData.percent(node)
    readonly property bool muted: Data.AudioData.usable(node) && node.audio.muted
    readonly property color tone: badge.muted ? root.tokens.alert : badge.value < 0 ? root.tokens.muted : badge.accent
    implicitWidth: badgeRow.implicitWidth + 18
    implicitHeight: 26
    radius: 13
    color: Qt.alpha(badge.tone, 0.06)
    border.color: Qt.alpha(badge.tone, 0.22)
    Row {
      id: badgeRow
      anchors.centerIn: parent
      spacing: 6
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 4; height: 4; radius: 2
        color: badge.tone
        opacity: badge.muted || badge.value <= 0 ? 0.45 : 1
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: badge.muted ? "MUTED" : badge.value < 0 ? "—" : badge.value + "%"
        color: badge.tone
        font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 0.5 }
      }
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
    readonly property var devices: output ? Data.AudioData.outputs : Data.AudioData.inputs
    readonly property var current: output ? Data.AudioData.sink : Data.AudioData.source
    readonly property bool ready: Data.AudioData.usable(current)
    readonly property color accent: output ? root.tokens.cyan : root.tokens.gold
    contentSpacing: 14
    RowLayout {
      Layout.fillWidth: true
      spacing: 12
      DeviceMark {
        output: card.output
        node: card.current
        accent: card.accent
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 3
        Eyebrow { text: card.output ? "OUTPUT" : "INPUT"; color: card.accent }
        Text {
          Layout.fillWidth: true
          text: card.ready ? Data.AudioData.label(card.current) : card.output ? "No output device" : "No input device"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: root.tokens.text
          font { family: root.tokens.font; pixelSize: 16; weight: Font.Medium }
        }
        Caption {
          text: card.ready ? (card.output ? "Playback · " : "Capture · ")
            + card.devices.length + (card.devices.length === 1 ? " device available" : " devices available")
            : "Waiting for PipeWire to expose this device"
          font.pixelSize: 10
        }
      }
      LevelBadge {
        Layout.alignment: Qt.AlignTop
        node: card.current
        accent: card.accent
      }
    }
    VolumeControl {
      tokens: root.tokens
      node: card.current
      label: card.output ? "Output volume" : "Microphone volume"
      subtitle: card.output ? "All audio leaves through this device." : "Apps use this microphone by default."
      prominent: true
      accent: card.accent
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6
      Eyebrow { text: "DEFAULT DEVICE"; color: root.tokens.muted }
      ComboBox {
        id: selector
        Layout.fillWidth: true
        implicitHeight: 40
        leftPadding: 12; rightPadding: 32
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
          font { family: root.tokens.font; pixelSize: 11 }
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
          radius: 7
          color: selector.hovered || selector.popup.visible ? Qt.alpha(card.accent, 0.06) : root.tokens.surface
          border.color: selector.activeFocus ? card.accent : root.tokens.border
        }
        delegate: ItemDelegate {
          id: option
          required property int index
          required property string modelData
          width: selector.width - 2
          implicitHeight: 38
          highlighted: selector.highlightedIndex === index
          Accessible.name: option.modelData
          contentItem: RowLayout {
            spacing: 8
            Components.SoundGlyph {
              Layout.preferredWidth: 17
              Layout.preferredHeight: 17
              kind: card.devices[option.index] ? Data.AudioData.glyph(card.devices[option.index]) : ""
              ink: option.index === selector.currentIndex ? card.accent : root.tokens.muted
            }
            Text {
              Layout.fillWidth: true
              text: option.modelData
              textFormat: Text.PlainText
              color: option.index === selector.currentIndex ? card.accent : root.tokens.text
              font { family: root.tokens.font; pixelSize: 11 }
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
            }
            Rectangle {
              Layout.preferredWidth: 5
              Layout.preferredHeight: 5
              radius: 2.5
              color: option.index === selector.currentIndex ? card.accent : "transparent"
            }
          }
          background: Rectangle {
            radius: 5
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
            radius: 8
            color: root.tokens.surface
            border.color: Qt.alpha(card.accent, 0.24)
          }
        }
      }
      Caption {
        text: card.ready ? "Choose where " + (card.output ? "sound is routed." : "the microphone sends audio.")
          : "Connect a device to make it available here."
        font.pixelSize: 10
      }
    }
  }
  ColumnLayout {
    width: root.availableWidth
    spacing: 12
    Rectangle {
      Layout.fillWidth: true
      visible: !Data.AudioData.available
      implicitHeight: unavailableRow.implicitHeight + 24
      radius: 8
      color: Qt.alpha(root.tokens.alert, 0.07)
      border.color: Qt.alpha(root.tokens.alert, 0.3)
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
    DeviceCard { objectName: "audioOutputCard"; output: true }
    DeviceCard { objectName: "audioInputCard"; output: false }
    Section {
      objectName: "audioMixerCard"
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Components.SoundGlyph {
          Layout.alignment: Qt.AlignVCenter
          kind: "mixer"
          ink: root.tokens.cyan
        }
        Eyebrow { Layout.fillWidth: true; text: "APPLICATION MIXER" }
        Rectangle {
          implicitWidth: streamCount.implicitWidth + 16
          implicitHeight: 22
          radius: 11
          color: Qt.alpha(root.tokens.cyan, 0.06)
          border.color: Qt.alpha(root.tokens.cyan, 0.18)
          Text {
            id: streamCount
            anchors.centerIn: parent
            text: Data.AudioData.playback.length === 0 ? "IDLE"
              : String(Data.AudioData.playback.length).padStart(2, "0")
                + (Data.AudioData.playback.length === 1 ? " STREAM" : " STREAMS")
            color: Data.AudioData.playback.length === 0 ? root.tokens.muted : root.tokens.cyan
            font { family: root.tokens.mono; pixelSize: 8; letterSpacing: 0.8 }
          }
        }
      }
      Rectangle {
        Layout.fillWidth: true
        visible: Data.AudioData.playback.length === 0
        implicitHeight: emptyBody.implicitHeight + 32
        radius: 8
        color: Qt.alpha(root.tokens.surface, 0.55)
        border.color: root.tokens.border
        ColumnLayout {
          id: emptyBody
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
          spacing: 8
          Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.bottomMargin: 2
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: Qt.alpha(root.tokens.cyan, 0.04)
              border.color: Qt.alpha(root.tokens.muted, 0.16)
            }
            Components.SoundGlyph {
              anchors.centerIn: parent
              kind: "mixer"
              ink: root.tokens.muted
            }
          }
          Text {
            Layout.fillWidth: true
            text: "Nothing playing"
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            color: root.tokens.text
            font { family: root.tokens.font; pixelSize: 14; weight: Font.Medium }
          }
          Text {
            Layout.fillWidth: true
            text: "Play audio in an app to control its volume here."
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: root.tokens.muted
            font { family: root.tokens.font; pixelSize: 11 }
          }
        }
      }
      Repeater {
        model: Data.AudioData.playback
        Rectangle {
          id: stream
          required property var modelData
          readonly property bool muted: Data.AudioData.usable(modelData) && modelData.audio.muted
          Layout.fillWidth: true
          implicitHeight: streamBody.implicitHeight + 24
          radius: 8
          color: Qt.alpha(root.tokens.surface, 0.55)
          border.color: Qt.alpha(stream.muted ? root.tokens.muted : root.tokens.cyan, 0.16)
          RowLayout {
            id: streamBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10
            Rectangle {
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: 32
              Layout.preferredHeight: 32
              Layout.topMargin: 2
              radius: 8
              color: Qt.alpha(root.tokens.cyan, stream.muted ? 0.035 : 0.07)
              border.color: Qt.alpha(stream.muted ? root.tokens.muted : root.tokens.cyan, 0.2)
              Components.SoundGlyph {
                anchors.centerIn: parent
                width: 20; height: 20
                kind: "stream"
                ink: stream.muted ? root.tokens.muted : root.tokens.cyan
              }
            }
            VolumeControl {
              Layout.fillWidth: true
              tokens: root.tokens
              node: stream.modelData
              label: Data.AudioData.appName(stream.modelData)
              subtitle: stream.modelData.properties["media.name"] || Data.AudioData.label(stream.modelData)
            }
          }
        }
      }
      Caption {
        visible: Data.AudioData.playback.length > 0
        text: "Each application keeps its own volume and mute state."
        font.pixelSize: 10
      }
    }
  }
}
