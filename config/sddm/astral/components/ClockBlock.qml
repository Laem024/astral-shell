import QtQuick

Column {
  id: root
  required property var tokens
  property date dateTime: new Date()
  property bool compact: false

  spacing: root.compact ? 7 : 12

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
    color: root.tokens.gold
    horizontalAlignment: Text.AlignHCenter
    font {
      family: root.tokens.mono
      pixelSize: root.compact ? 10 : 11
      letterSpacing: root.compact ? 1.8 : 2.4
      weight: Font.Medium
    }
  }

  Item {
    width: root.width
    height: clockRow.implicitHeight

    Row {
      id: clockRow
      anchors.centerIn: parent
      spacing: root.compact ? 8 : 12

      Text {
        id: clockText
        text: root.timeText
        color: root.tokens.text
        font {
          family: root.tokens.font
          pixelSize: root.compact ? 84 : 132
          weight: Font.ExtraLight
          letterSpacing: root.compact ? -4 : -6
        }
      }

      Item {
        width: meridiem.implicitWidth
        height: clockText.implicitHeight
        visible: root.tokens.clockFormat !== "24h"

        Text {
          id: meridiem
          anchors.top: parent.top
          anchors.topMargin: root.compact ? 10 : 20
          text: root.meridiemText
          color: root.tokens.muted
          font {
            family: root.tokens.mono
            pixelSize: root.compact ? 10 : 12
            letterSpacing: 1
          }
        }
      }
    }
  }
}
