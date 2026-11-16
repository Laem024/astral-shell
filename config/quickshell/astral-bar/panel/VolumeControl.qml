pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data
import "../components" as Components

ColumnLayout {
  id: root
  required property Design.Theme tokens
  required property var node
  required property string label
  property string subtitle: ""
  property bool prominent: false
  property color accent: tokens.cyan
  readonly property int percent: Data.AudioData.percent(node)
  readonly property bool usable: percent >= 0
  readonly property bool muted: usable && node.audio.muted
  Layout.fillWidth: true
  spacing: root.prominent ? 10 : 6
  RowLayout {
    Layout.fillWidth: true
    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: 4
      Text {
        Layout.fillWidth: true
        text: root.label
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.tokens.text
        font { family: root.tokens.font; pixelSize: root.prominent ? 20 : 13; weight: Font.Medium }


      }
      Text {
        Layout.fillWidth: true
        visible: root.subtitle !== "" || root.muted
        text: root.muted ? "Muted" : root.subtitle
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.muted ? root.tokens.gold : root.tokens.muted
        font { family: root.tokens.font; pixelSize: 10 }


      }
    }
    Text {
      text: root.usable ? root.percent + "%" : "N/A"
      color: root.muted ? root.tokens.muted : root.accent
      font { family: root.tokens.mono; pixelSize: root.prominent ? 27 : 13; weight: Font.Medium }
    }
  }
  RowLayout {
    Layout.fillWidth: true
    Slider {
      id: slider
      implicitWidth: 120
      implicitHeight: 26
      Layout.fillWidth: true
      enabled: root.usable
      from: 0; to: 1; stepSize: 0.01
      value: root.usable ? Math.min(1, root.percent / 100) : 0
      onMoved: Data.AudioData.setVolume(root.node, value)
      Accessible.name: root.label + " volume"
      background: Rectangle {
        x: slider.leftPadding
        y: (slider.height - height) / 2
        width: slider.availableWidth
        height: 4
        radius: 2
        color: Qt.alpha(root.tokens.muted, 0.16)
        Rectangle {
          width: parent.width * slider.visualPosition
          height: parent.height
          radius: 2
          color: root.muted ? root.tokens.muted : root.usable ? root.accent : root.tokens.muted
        }
      }
      handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: (slider.height - height) / 2
        width: 12; height: 12; radius: 6
        color: root.muted ? root.tokens.muted : root.usable ? root.accent : root.tokens.muted
        border.width: slider.activeFocus ? 2 : 0
        border.color: root.tokens.gold
      }
    }
    Button {
      id: muteButton
      implicitWidth: 38
      implicitHeight: 36
      padding: 0
      text: root.muted ? "Unmute" : "Mute"
      enabled: root.usable
      hoverEnabled: true
      focusPolicy: Qt.StrongFocus
      checkable: true
      checked: root.muted
      Accessible.name: text + " " + root.label
      onClicked: Data.AudioData.toggleMute(root.node)
      readonly property color ink: !enabled ? root.tokens.muted : root.muted ? root.tokens.alert : root.accent
      background: Rectangle {
        radius: 10
        color: !muteButton.enabled ? "transparent"
          : root.muted ? Qt.alpha(root.tokens.alert, muteButton.down ? 0.24 : muteButton.hovered ? 0.19 : 0.12)
          : Qt.alpha(root.accent, muteButton.down ? 0.18 : muteButton.hovered ? 0.12 : 0.05)
        border.width: muteButton.activeFocus ? 2 : 1
        border.color: muteButton.activeFocus ? root.accent
          : root.muted ? Qt.alpha(root.tokens.alert, 0.5) : root.tokens.border
      }
      contentItem: Item {
        opacity: muteButton.enabled ? 1 : 0.4
        Components.SoundGlyph {
          anchors.centerIn: parent
          width: 22; height: 22
          kind: "speaker"
          muted: root.muted
          level: root.usable ? Math.min(1, root.percent / 100) : 0
          ink: muteButton.ink
        }
      }



    }
  }
}
