pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data
import "../data/TimeFormat.js" as TimeFormat

ScrollView {
  id: root
  required property Design.Theme tokens
  required property var settings
  readonly property var weatherData: Data.WeatherData
  readonly property var weather: weatherData.activeWeather
  readonly property var current: weather && weather.current ? weather.current : null
  readonly property var daily: weather && weather.daily ? weather.daily : null
  readonly property bool isTwelveHour: settings.value.clockFormat === "12h"
  readonly property string degrees: weather && weather.current_units && weather.current_units.temperature_2m
    ? weather.current_units.temperature_2m
    : settings.value.weather.temperatureUnit === "fahrenheit" ? "°F" : "°C"
  readonly property string windUnit: weather && weather.current_units && weather.current_units.wind_speed_10m
    ? weather.current_units.wind_speed_10m
    : settings.value.weather.windUnit === "mph" ? "mph" : settings.value.weather.windUnit === "ms" ? "m/s"
      : settings.value.weather.windUnit === "kn" ? "kn" : "km/h"
  readonly property real forecastLow: daily && daily.temperature_2m_min.length ? Math.min(...daily.temperature_2m_min) : 0
  readonly property real forecastHigh: daily && daily.temperature_2m_max.length ? Math.max(...daily.temperature_2m_max) : 1
  readonly property var monthNames: [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]
  readonly property var weekdayNames: [
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
  ]
  readonly property var weekdayShortNames: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
  readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
  property date currentDate: new Date()
  readonly property var zoned: TimeFormat.zoned(currentDate.getTime(), weatherData.offsetFor(currentDate.getTime()))
  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()
  property bool navigated: false
  readonly property string monthName: monthNames[zoned.month]
  readonly property string dateText: zoned.day + " " + monthName + " " + zoned.year
  readonly property string fullDateText: weekdayNames[zoned.weekday] + ", " + dateText
  readonly property string timeText: TimeFormat.clockText(zoned, isTwelveHour)
  readonly property string period: isTwelveHour ? TimeFormat.periodText(zoned) : ""
  readonly property string offsetText: TimeFormat.offsetLabel(weatherData.offsetFor(currentDate.getTime()))
  readonly property string locationOrigin: weatherData.locationSource === "IP" ? "AUTO LOCATION"
    : weatherData.locationSource === "CACHED" ? "SAVED LOCATION" : "SYSTEM TIME"
  readonly property color originAccent: weatherData.locationSource === "IP" ? tokens.cyan
    : weatherData.locationSource === "CACHED" ? tokens.gold : tokens.muted
  readonly property string weatherStatus: weatherData.loading ? "UPDATING…"
    : !weather ? (weatherData.offline ? "OFFLINE" : "UNAVAILABLE")
    : weatherData.weatherStale ? "SAVED " + stamp(weatherData.weatherUpdated)
    : "UPDATED " + stamp(weatherData.weatherUpdated)

  function stamp(epoch): string {
    if (!epoch) return "—";
    return TimeFormat.clockText(TimeFormat.zoned(epoch, weatherData.offsetFor(epoch)), isTwelveHour);
  }
  function calendar(year: int, month: int): var {
    const start = (new Date(year, month, 1).getDay() - firstDay + 7) % 7;
    const days = new Date(year, month + 1, 0).getDate();
    return Array.from({length: Math.ceil((start + days) / 7) * 7}, (_, i) => i >= start && i < start + days ? i - start + 1 : 0);
  }
  function move(delta: int): void {
    const date = new Date(year, month + delta, 1);
    year = date.getFullYear();
    month = date.getMonth();
    navigated = year !== zoned.year || month !== zoned.month;
  }
  function backToToday(): void {
    year = zoned.year;
    month = zoned.month;
    navigated = false;
  }
  function condition(code: int): string {
    if (code === 0) return "Clear sky";
    if (code <= 2) return "Partly cloudy";
    if (code === 3) return "Overcast";
    if (code <= 48) return "Fog";
    if (code <= 57) return "Drizzle";
    if (code <= 67) return "Rain";
    if (code <= 77) return "Snow";
    if (code <= 82) return "Showers";
    if (code <= 86) return "Snow showers";
    return "Thunderstorms";
  }
  function shortCondition(code: int): string {
    if (code === 0) return "Clear";
    if (code <= 2) return "Clouds";
    if (code === 3) return "Overcast";
    if (code <= 48) return "Fog";
    if (code <= 57) return "Drizzle";
    if (code <= 67) return "Rain";
    if (code <= 77) return "Snow";
    if (code <= 82) return "Showers";
    if (code <= 86) return "Flurries";
    return "Storms";
  }
  function dayLabel(iso: string): string {
    const parts = iso.split("-").map(Number);
    if (parts.length !== 3 || parts.some(value => !Number.isFinite(value))) return iso;
    const weekday = new Date(parts[0], parts[1] - 1, parts[2]).getDay();
    return weekdayShortNames[weekday] + " " + TimeFormat.pad2(parts[2]);
  }

  Component.onCompleted: {
    year = zoned.year;
    month = zoned.month;
    weatherData.activate(false);
  }
  onZonedChanged: if (!navigated) {
    year = zoned.year;
    month = zoned.month;
  }
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.currentDate = new Date()
  }

  contentWidth: availableWidth
  clip: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

  component Eyebrow: Text {
    color: root.tokens.cyan
    textFormat: Text.PlainText
    font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1 }
  }
  component Metric: ColumnLayout {
    id: metric
    required property string label
    required property string value
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: 4
    Text {
      Layout.fillWidth: true
      text: metric.value
      color: root.tokens.text
      elide: Text.ElideRight
      font { family: root.tokens.mono; pixelSize: 13 }
    }
    Text {
      Layout.fillWidth: true
      text: metric.label
      color: root.tokens.muted
      elide: Text.ElideRight
      font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 0.6 }
    }
  }
  component Badge: Rectangle {
    id: badge
    property alias label: badgeText.text
    property color accent: root.tokens.cyan
    implicitWidth: badgeText.implicitWidth + 16
    implicitHeight: 20
    radius: 10
    color: Qt.alpha(badge.accent, 0.08)
    border.color: Qt.alpha(badge.accent, 0.22)
    Text {
      id: badgeText
      anchors.centerIn: parent
      color: badge.accent
      textFormat: Text.PlainText
      font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 0.7 }
    }
  }
  component Divider: Rectangle {
    Layout.fillWidth: true
    implicitHeight: 1
    color: root.tokens.border
  }

  ColumnLayout {
    width: root.availableWidth
    spacing: 12
    PageIntro {
      tokens: root.tokens
      title: "Make room for today"
      subtitle: root.fullDateText
      symbol: "calendar"
      accent: root.tokens.gold
    }
    PanelCard {
      tokens: root.tokens
      accent: root.tokens.gold
      contentSpacing: 18
      border.color: Qt.alpha(root.tokens.cyan, 0.18)
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.tint(root.tokens.background, Qt.alpha(root.tokens.cyan, 0.06)) }
        GradientStop { position: 1; color: root.tokens.background }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Eyebrow { text: "CALENDAR" }
        Item { Layout.fillWidth: true }
        RowLayout {
          spacing: 4
          Text {
            text: root.timeText
            color: root.tokens.text
            font { family: root.tokens.mono; pixelSize: 14 }
          }
          Text {
            visible: root.period !== ""
            text: root.period
            color: root.tokens.muted
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 2
            font { family: root.tokens.mono; pixelSize: 9 }
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 1
          Text {
            Layout.fillWidth: true
            text: root.monthNames[root.month]
            color: root.tokens.text
            elide: Text.ElideRight
            font { family: root.tokens.font; pixelSize: 26; weight: Font.DemiBold }
          }
          Text {
            text: String(root.year)
            color: root.tokens.muted
            font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 1 }
          }
        }
        PanelButton {
          tokens: root.tokens
          text: "Today"
          implicitHeight: 32
          visible: root.navigated
          Accessible.name: "Back to today"
          onClicked: root.backToToday()
        }
        PanelButton {
          tokens: root.tokens
          text: "‹"
          implicitHeight: 32
          Accessible.name: "Previous month"
          onClicked: root.move(-1)
        }
        PanelButton {
          tokens: root.tokens
          text: "›"
          implicitHeight: 32
          Accessible.name: "Next month"
          onClicked: root.move(1)
        }
      }
      GridLayout {
        Layout.fillWidth: true
        columns: 7
        uniformCellWidths: true
        columnSpacing: 4
        rowSpacing: 4
        Repeater {
          model: 7
          Text {
            required property int index
            readonly property int weekday: (root.firstDay + index) % 7
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.weekdayShortNames[weekday]
            color: root.tokens.muted
            horizontalAlignment: Text.AlignHCenter
            font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 0.8 }
          }
        }
        Repeater {
          model: root.calendar(root.year, root.month)
          Rectangle {
            id: dayCell
            required property int modelData
            readonly property bool currentDay: modelData === root.zoned.day
              && root.month === root.zoned.month && root.year === root.zoned.year
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            implicitHeight: 36
            radius: root.tokens.rowRadius
            color: currentDay ? root.tokens.gold
              : modelData > 0 ? Qt.alpha(root.tokens.text, hover.hovered ? 0.09 : 0.025) : "transparent"
            border.color: currentDay ? root.tokens.gold : "transparent"
            Text {
              anchors.centerIn: parent
              text: dayCell.modelData || ""
              color: dayCell.currentDay ? root.tokens.background : root.tokens.text
              font { family: root.tokens.mono; pixelSize: 11; weight: dayCell.currentDay ? Font.DemiBold : Font.Normal }
            }
            HoverHandler { id: hover }
          }
        }
      }
      Divider {}
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
          Layout.fillWidth: true
          text: root.fullDateText
          color: root.tokens.muted
          elide: Text.ElideRight
          font { family: root.tokens.font; pixelSize: 10 }
        }
        Text {
          text: root.offsetText
          color: root.tokens.muted
          elide: Text.ElideRight
          font { family: root.tokens.mono; pixelSize: 9 }
        }
      }
    }
    PanelCard {
      tokens: root.tokens
      contentSpacing: 14
      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Eyebrow { text: "WEATHER" }
        Item { Layout.fillWidth: true }
        Badge { label: root.locationOrigin; accent: root.originAccent }
        PanelButton {
          tokens: root.tokens
          text: "↻"
          implicitHeight: 28
          Accessible.name: "Refresh weather"
          enabled: !root.weatherData.loading
          onClicked: root.weatherData.activate(true)
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 3
        Text {
          Layout.fillWidth: true
          text: root.weatherData.locationLabel
          color: root.tokens.text
          wrapMode: Text.Wrap
          font { family: root.tokens.font; pixelSize: 15; weight: Font.Medium }
        }
        Text {
          Layout.fillWidth: true
          text: root.current ? root.condition(root.current.weather_code)
            : root.weatherData.loading ? "Updating…" : (root.weatherData.error || "Weather unavailable")
          color: root.current ? root.tokens.gold : root.tokens.muted
          wrapMode: Text.Wrap
          font { family: root.tokens.font; pixelSize: 11 }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Text {
          Layout.fillWidth: true
          text: root.current ? Math.round(root.current.temperature_2m) + root.degrees : "—"
          color: root.tokens.text
          elide: Text.ElideRight
          font { family: root.tokens.font; pixelSize: 42; weight: Font.Light }
        }
        Item {
          Layout.preferredWidth: 60
          Layout.preferredHeight: 60
          visible: root.current !== null
          opacity: root.current && root.current.weather_code === 0 ? 1 : 0
          Rectangle { anchors.centerIn: parent; width: 44; height: 44; radius: 22; color: Qt.alpha(root.tokens.gold, 0.08) }
          Rectangle { anchors.centerIn: parent; width: 24; height: 24; radius: 12; color: root.tokens.gold }
          Repeater {
            model: 8
            Item {
              required property int index
              anchors.fill: parent
              rotation: index * 45
              Rectangle { x: 29; y: 3; width: 2; height: 7; radius: 1; color: root.tokens.gold }
            }
          }
        }
      }
      Divider {}
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Metric { label: "FEELS LIKE"; value: root.current ? Math.round(root.current.apparent_temperature) + root.degrees : "—" }
        Rectangle { implicitWidth: 1; implicitHeight: 28; color: root.tokens.border }
        Metric { label: "HUMIDITY"; value: root.current ? root.current.relative_humidity_2m + "%" : "—" }
        Rectangle { implicitWidth: 1; implicitHeight: 28; color: root.tokens.border }
        Metric { label: "WIND · " + root.windUnit.toUpperCase(); value: root.current ? String(Math.round(root.current.wind_speed_10m)) : "—" }
      }
      Text {
        Layout.fillWidth: true
        text: root.weatherStatus
        color: root.weatherData.offline ? root.tokens.alert : root.tokens.muted
        wrapMode: Text.Wrap
        font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 0.6 }
      }
    }
    PanelCard {
      tokens: root.tokens
      title: "WEEK AHEAD"
      accent: root.tokens.gold
      contentSpacing: 12
      Repeater {
        model: root.daily ? root.daily.time : []
        RowLayout {
          id: forecast
          required property string modelData
          required property int index
          readonly property real low: root.daily.temperature_2m_min[index]
          readonly property real high: root.daily.temperature_2m_max[index]
          readonly property bool today: index === 0
          Layout.fillWidth: true
          spacing: 10
          Text {
            Layout.preferredWidth: 58
            text: root.dayLabel(forecast.modelData)
            color: forecast.today ? root.tokens.cyan : root.tokens.muted
            elide: Text.ElideRight
            font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 0.5 }
          }
          Text {
            Layout.preferredWidth: 52
            text: root.shortCondition(root.daily.weather_code[forecast.index])
            color: forecast.today ? root.tokens.text : root.tokens.muted
            elide: Text.ElideRight
            font { family: root.tokens.font; pixelSize: 9 }
          }
          Text {
            text: Math.round(forecast.low) + "°"
            color: root.tokens.muted
            font { family: root.tokens.mono; pixelSize: 10 }
          }
          Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            implicitHeight: 4
            radius: 2
            color: Qt.alpha(root.tokens.muted, 0.12)
            Rectangle {
              readonly property real span: Math.max(1, root.forecastHigh - root.forecastLow)
              x: parent.width * (forecast.low - root.forecastLow) / span
              width: parent.width * Math.max(0, forecast.high - forecast.low) / span
              height: 4; radius: 2
              color: root.tokens.gold
            }
          }
          Text {
            text: Math.round(forecast.high) + "°"
            color: root.tokens.text
            font { family: root.tokens.mono; pixelSize: 10 }
          }
        }
      }
      Text {
        Layout.fillWidth: true
        visible: !root.daily
        text: "Forecast unavailable"
        color: root.tokens.muted
        font { family: root.tokens.font; pixelSize: 12 }
      }
    }
  }
}
