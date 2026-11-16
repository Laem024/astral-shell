pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
  id: root
  required property var tokens
  required property var entry
  property bool compact: false
  implicitHeight: root.compact ? 31 : 35

  HoverHandler { id: hover }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: 1
    anchors.rightMargin: 1
    radius: root.tokens.rowRadius
    color: hover.hovered ? Qt.alpha(root.tokens.text, 0.045) : "transparent"
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: root.compact ? 5 : 7
    anchors.rightMargin: root.compact ? 5 : 7
    spacing: root.compact ? 6 : 9

    Text {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      text: root.entry.label
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: hover.hovered ? root.tokens.text : Qt.alpha(root.tokens.text, 0.9)
      font {
        family: root.tokens.font
        pixelSize: root.compact ? 11 : 12
      }
    }

    Row {
      Layout.alignment: Qt.AlignVCenter
      spacing: root.compact ? 2 : 3

      Text {
        visible: root.entry.keys.length === 0
        text: "—"
        color: root.tokens.muted
        font {
          family: root.tokens.mono
          pixelSize: root.compact ? 9 : 10
        }
      }

      Repeater {
        model: root.entry.keys
        delegate: Row {
          id: chord
          required property var modelData
          required property int index
          spacing: root.compact ? 2 : 3

          KeyCap {
            tokens: root.tokens
            label: chord.modelData
            compact: root.compact
          }
          Text {
            visible: chord.index < root.entry.keys.length - 1
            text: "+"
            color: Qt.alpha(root.tokens.muted, 0.65)
            anchors.verticalCenter: parent.verticalCenter
            font {
              family: root.tokens.mono
              pixelSize: root.compact ? 8 : 9
            }
          }
        }
      }
    }
  }
}
