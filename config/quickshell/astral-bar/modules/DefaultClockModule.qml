pragma ComponentBehavior: Bound
import QtQuick
import "../../common" as Design
import "../data/TimeFormat.js" as TimeFormat

Item {
  id: root
  objectName: "clock"
  required property Design.Theme tokens
  required property date dateTime
  property int offsetSeconds: 0
  signal activated()
  readonly property bool hovered: hover.hovered
  property bool vertical: false
  readonly property bool isTwelveHour: tokens.settings.value.clockFormat === "12h"
  readonly property var zoned: TimeFormat.zoned(dateTime.getTime(), offsetSeconds)
  readonly property string formattedTime: TimeFormat.clockText(zoned, isTwelveHour)
  readonly property string period: isTwelveHour ? TimeFormat.periodText(zoned) : ""
  readonly property string date: {
    const weekday = zoned.weekday === 0 ? 7 : zoned.weekday;
    const locale = Qt.locale("en_US");
    const day = locale.standaloneDayName(weekday, Locale.ShortFormat).toUpperCase();
    const month = locale.standaloneMonthName(zoned.month + 1, Locale.ShortFormat).toUpperCase();
    return day + " · " + TimeFormat.pad2(zoned.day) + " " + month;
  }
  readonly property int horizontalPadding: 8
  property color accent: hover.hovered ? tokens.cyan : tokens.text
  implicitWidth: vertical ? 50
    : Math.max(96, Math.max(timeRow.implicitWidth, dateLabel.implicitWidth) + 2 * horizontalPadding)
  implicitHeight: stack.implicitHeight + 2
  Behavior on accent { ColorAnimation { duration: root.tokens.hoverDuration } }
  Column {
    id: stack
    width: root.width
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.vertical ? 6 : 1
    Row {
      id: timeRow
      objectName: "clockTimeRow"
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 3
      Text {
        id: timeLabel
        objectName: "clockTime"
        text: root.vertical ? root.formattedTime.replace(":", "\n") : root.formattedTime
        horizontalAlignment: Text.AlignHCenter
        color: root.accent
        font.family: root.tokens.mono
        font.pixelSize: root.vertical ? 23 : root.tokens.clockSize
        font.weight: Font.DemiBold
        lineHeight: 0.9
      }
      Text {
        objectName: "clockPeriod"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        visible: root.period !== ""
        text: root.period
        color: root.tokens.muted
        font.family: root.tokens.mono
        font.pixelSize: 9
      }
    }
    Text {
      id: dateLabel
      objectName: "clockDate"
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.vertical ? root.date.split("·")[1].trim() : root.date.replace(" · ", "   /   ")
      color: root.tokens.muted
      font.family: root.tokens.mono
      font.pixelSize: 9
      font.letterSpacing: 0.8
    }
  }
  TapHandler { onTapped: root.activated() }
  HoverHandler { id: hover }
}
