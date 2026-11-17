import QtQuick

Column {
  id: root
  required property var tokens
  property date dateTime: new Date()
  property bool compact: false

  spacing: root.compact ? 4 : 8

  readonly property var englishLocale: Qt.locale("en_US")
  readonly property string dateText: root.dateTime
    .toLocaleDateString(root.englishLocale, "dddd, d MMMM")
    .replace(", ", "  ·  ")
    .toUpperCase()
  readonly property string timeText: root.tokens.clockFormat === "24h"
    ? root.dateTime.toLocaleTimeString(root.englishLocale, "HH:mm")
    : root.dateTime.toLocaleTimeString(root.englishLocale, "hh:mm AP").replace(/\s*(AM|PM)$/i, "")
  readonly property string meridiemText: root.dateTime.toLocaleTimeString(root.englishLocale, "AP")

  Text {
    width: root.width
    text: root.dateText
    color: root.tokens.muted
    horizontalAlignment: Text.AlignHCenter
    font {
      family: root.tokens.mono
      pixelSize: root.tokens.captionSize + 1
      letterSpacing: 2
      weight: Font.Medium
    }
  }

  Item {
    width: root.width
    height: clockRow.implicitHeight

    Row {
      id: clockRow
      anchors.centerIn: parent
      spacing: 8

      Text {
        id: clockText
        text: root.timeText
        color: root.tokens.text
        font {
          family: root.tokens.mono
          pixelSize: root.compact ? 56 : root.tokens.displaySize
          weight: Font.Light
          letterSpacing: -2
        }
      }

      Item {
        width: meridiem.implicitWidth
        height: clockText.implicitHeight
        visible: root.tokens.clockFormat !== "24h"

        Text {
          id: meridiem
          anchors.top: parent.top
          anchors.topMargin: root.compact ? 8 : 16
          text: root.meridiemText
          color: root.tokens.muted
          font {
            family: root.tokens.mono
            pixelSize: root.tokens.captionSize + 2
            letterSpacing: 1
          }
        }
      }
    }
  }
}
