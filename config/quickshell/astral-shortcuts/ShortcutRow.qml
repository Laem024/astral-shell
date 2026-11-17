pragma ComponentBehavior: Bound
import "../common" as Common
import QtQuick
import QtQuick.Layouts

Item {
  id: root
  required property var tokens
  required property var entry
  property bool compact: false
  implicitHeight: root.compact ? 32 : 36

  HoverHandler { id: hover }

  Rectangle {
    anchors.fill: parent
    radius: root.tokens.rowRadius
    color: hover.hovered ? root.tokens.raised : "transparent"
    border.width: 1
    border.color: hover.hovered ? root.tokens.hairline : "transparent"
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: root.compact ? 8 : 10
    anchors.rightMargin: root.compact ? 8 : 10
    spacing: root.compact ? 8 : 12

    Text {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      text: root.entry.label
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: hover.hovered ? root.tokens.text : Qt.alpha(root.tokens.text, 0.88)
      font {
        family: root.tokens.font
        pixelSize: root.compact ? 11 : 12
      }
    }

    Row {
      Layout.alignment: Qt.AlignVCenter
      spacing: root.compact ? 3 : 4

      Text {
        visible: root.entry.keys.length === 0
        text: "—"
        color: root.tokens.muted
        font {
          family: root.tokens.mono
          pixelSize: root.compact ? 10 : 11
        }
      }

      Repeater {
        model: root.entry.keys
        delegate: Row {
          id: chord
          required property var modelData
          required property int index
          spacing: root.compact ? 3 : 4

          KeyCap {
            tokens: root.tokens
            label: chord.modelData
            compact: root.compact
          }
          Text {
            visible: chord.index < root.entry.keys.length - 1
            text: "+"
            color: root.tokens.muted
            anchors.verticalCenter: parent.verticalCenter
            font {
              family: root.tokens.mono
              pixelSize: root.compact ? 9 : 10
            }
          }
        }
      }
    }
  }
}
