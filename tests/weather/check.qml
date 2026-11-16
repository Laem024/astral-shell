import QtQuick
import QtQuick.Window
import Quickshell
import "./astral-bar/data" as Data
import "./astral-bar/data/TimeFormat.js" as TimeFormat
import "./common" as Design
import "./astral-bar/panel" as Panel
import "./astral-bar/settings" as Settings
import "./astral-bar/modules" as Modules

Scope {
  id: root
  readonly property var weather: Data.WeatherData
  readonly property string mode: Quickshell.env("ASTRAL_WEATHER_TEST_MODE") || "online"
  property int ticks: 0
  property bool done: false
  Design.Theme { id: theme; settings: Settings.SettingsData }
  Modules.DefaultClockModule {
    id: clockProbe
    visible: false
    tokens: theme
    dateTime: new Date(0)
    offsetSeconds: -14400
  }
  Modules.ClockModule {
    id: wrapperProbe
    visible: false
    tokens: theme
    dateTime: new Date(0)
    offsetSeconds: -14400
  }
  function clockVisual(item) {
    if (item.objectName === "clock") return item;
    for (const child of item.children) {
      const match = clockVisual(child);
      if (match) return match;
    }
    return null;
  }
  Window {
    id: weatherWindow
    visible: true
    width: 400
    height: 680
    Panel.WeatherPage { anchors.fill: parent; tokens: theme; settings: Settings.SettingsData }
  }

  function check(ok, message) {
    if (!ok) {
      console.error("WEATHER_FAIL: " + message);
      Qt.exit(1);
    }
  }
  function finish(delay) {
    if (done) return;
    done = true;
    wait.interval = delay;
    wait.start();
  }
  function verifyTimeFormat() {
    const zoned = TimeFormat.zoned(0, -14400);
    root.check(zoned.year === 1969 && zoned.month === 11 && zoned.day === 31 && zoned.hour === 20,
      "zoned fields: " + JSON.stringify(zoned));
    root.check(TimeFormat.clockText(zoned, false) === "20:00", "24-hour formatting");
    root.check(TimeFormat.clockText(zoned, true) === "08:00" && TimeFormat.periodText(zoned) === "PM",
      "12-hour formatting");
    root.check(TimeFormat.offsetLabel(-14400) === "UTC-04:00", "negative offset label");
    root.check(TimeFormat.offsetLabel(19800) === "UTC+05:30", "half-hour offset label");
    root.check(clockProbe.formattedTime === "08:00" && clockProbe.period === "PM",
      "bar clock follows the location offset: " + clockProbe.formattedTime + " " + clockProbe.period);
  }

  Component.onCompleted: {
    weather.activate(true);
  }
  Timer {
    interval: 50
    repeat: true
    running: true
    onTriggered: {
      if (++root.ticks > 300) root.check(false, "timeout: " + root.mode + " loading=" + root.weather.loading
        + " error=" + root.weather.error);
      const visual = clockVisual(wrapperProbe);
      if (!visual || !clockProbe.formattedTime) return;
      verifyTimeFormat();
      root.check(visual.dateTime.getTime() === wrapperProbe.dateTime.getTime() && visual.offsetSeconds === wrapperProbe.offsetSeconds,
        "clock wrapper forwards date and offset");
      if (root.mode === "online") {
        if (root.weather.loading || !root.weather.hasWeather) return;
        root.check(root.weather.locationSource === "IP", "fresh source: " + root.weather.locationSource);
        root.check(root.weather.locationLabel === "Santiago de los Caballeros, Provincia de Santiago, DO",
          "fresh location: " + root.weather.locationLabel);
        root.check(root.weather.timezoneId === "America/Santo_Domingo", "fresh timezone: " + root.weather.timezoneId);
        root.check(root.weather.offsetFor(Date.now()) === -14400, "fresh offset");
        root.check(Math.round(root.weather.activeWeather.current.temperature_2m) === 29, "fresh temperature");
        root.check(root.weather.weatherFresh && !root.weather.weatherStale, "fresh weather state");
        root.finish(400);
      } else if (root.mode === "cached") {
        if (root.weather.loading) return;
        root.check(root.weather.locationSource === "CACHED", "cached source: " + root.weather.locationSource);
        root.check(root.weather.locationLabel === "Santiago de los Caballeros, Provincia de Santiago, DO",
          "cached location: " + root.weather.locationLabel);
        root.check(root.weather.offsetFor(Date.now()) === -14400, "cached offset");
        root.check(root.weather.hasWeather && root.weather.weatherStale, "cached weather retained");
        root.check(root.weather.offline, "cached weather is offline");
        root.finish(100);
      } else {
        if (root.weather.loading || root.weather.timezoneId !== "America/Santo_Domingo") return;
        root.check(root.weather.locationSource === "SYSTEM", "system source: " + root.weather.locationSource);
        root.check(root.weather.timezoneId === "America/Santo_Domingo", "system timezone: " + root.weather.timezoneId);
        root.check(root.weather.locationLabel === "Santo Domingo", "system location: " + root.weather.locationLabel);
        root.check(!root.weather.hasWeather, "no weather without cache");
        root.check(root.weather.offline, "system fallback is offline");
        root.finish(100);
      }
    }
  }
  Timer {
    id: wait
    onTriggered: {
      console.log("WEATHER_PASS " + root.mode);
      const snapshot = Quickshell.env("ASTRAL_WEATHER_SCREENSHOT");
      if (snapshot) {
        weatherWindow.contentItem.grabToImage(result => {
          result.saveToFile(snapshot + "-" + root.mode + ".png");
          Qt.quit();
        });
      } else Qt.quit();
    }
  }
}
