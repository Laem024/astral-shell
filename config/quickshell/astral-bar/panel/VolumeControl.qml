pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data
import "../components" as Components

// One slider row: track, live percentage and a mute toggle. Labels belong to the
// card that hosts the control, so every device and stream shares this layout.
RowLayout {
  id: root
  required property Design.Theme tokens
  required property var node
  required property string label
  property color accent: tokens.cyan
  readonly property int percent: Data.AudioData.percent(node)
  readonly property bool usable: percent >= 0
  readonly property bool muted: usable && node.audio.muted
  readonly property color tone: !usable || muted ? tokens.muted : accent
  Layout.fillWidth: true
  spacing: 10
  Slider {
    id: slider
    Layout.fillWidth: true
    implicitHeight: 24
    leftPadding: 0; rightPadding: 0
    enabled: root.usable
    from: 0; to: 1; stepSize: 0.01
    value: root.usable ? Math.min(1, root.percent / 100) : 0
    onMoved: Data.AudioData.setVolume(root.node, value)
    Accessible.name: root.label + " volume"
    background: Rectangle {
      x: slider.leftPadding
      y: (slider.height - height) / 2
      width: slider.availableWidth
      height: 4; radius: 2
      color: Qt.alpha(root.tokens.text, 0.1)
      Rectangle {
        width: parent.width * slider.visualPosition
        height: parent.height; radius: 2
        color: root.tone
      }
    }
    handle: Rectangle {
      x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
      y: (slider.height - height) / 2
      width: 14; height: 14; radius: 7
      color: root.tone
      border.width: 2
      border.color: slider.activeFocus ? root.tokens.cyan : root.tokens.raised
    }
  }
  Text {
    Layout.preferredWidth: 40
    horizontalAlignment: Text.AlignRight
    text: !root.usable ? "N/A" : root.muted ? "MUTE" : root.percent + "%"
    textFormat: Text.PlainText
    color: root.tone
    font { family: root.tokens.mono; pixelSize: 11; weight: Font.Medium }
  }
  Button {
    id: muteButton
    implicitWidth: 28
    implicitHeight: 28
    padding: 0
    text: root.muted ? "Unmute" : "Mute"
    enabled: root.usable
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    checkable: true
    checked: root.muted
    Accessible.name: text + " " + root.label
    onClicked: Data.AudioData.toggleMute(root.node)
    background: Rectangle {
      radius: root.tokens.rowRadius
      color: root.muted ? Qt.alpha(root.tokens.alert, muteButton.hovered ? 0.16 : 0.1)
        : muteButton.hovered ? Qt.alpha(root.tokens.text, 0.08) : "transparent"
      border.width: muteButton.activeFocus ? 2 : 0
      border.color: root.tokens.cyan
    }
    contentItem: Item {
      opacity: muteButton.enabled ? 1 : 0.4
      Components.SoundGlyph {
        anchors.centerIn: parent
        kind: "speaker"
        muted: root.muted
        level: root.usable ? Math.min(1, root.percent / 100) : 0
        ink: root.muted ? root.tokens.alert : root.tokens.text
      }
    }
  }
}
