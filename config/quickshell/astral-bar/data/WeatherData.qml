pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../settings" as Settings
import "TimeFormat.js" as TimeFormat
import "../../common" as Common

Singleton {
  id: root

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
  readonly property string baseState: stateHome.startsWith("/") ? stateHome : Quickshell.env("HOME") + "/.local/state"
  readonly property string directory: Common.Paths.cache + "/astral-bar"
  readonly property string cachePath: directory + "/weather.json"
  readonly property var weatherSettings: (Settings.SettingsData.value && Settings.SettingsData.value.weather)
    || ({ temperatureUnit: "celsius", windUnit: "kmh" })
  readonly property string temperatureUnit: weatherSettings.temperatureUnit === "fahrenheit" ? "fahrenheit" : "celsius"
  readonly property string windUnit: ["kmh", "mph", "ms", "kn"].includes(weatherSettings.windUnit) ? weatherSettings.windUnit : "kmh"
  readonly property int staleAfter: 15 * 60 * 1000
  readonly property int retryAfter: 5 * 60 * 1000
  readonly property int refreshAfter: 30 * 60 * 1000
  readonly property int geolocateAfter: 60 * 60 * 1000

  property var location: null
  property var systemLocation: null
  property string systemZone: ""
  property var weather: null
  property var weatherLocation: null
  property var weatherTarget: null
  property var geoFallback: null
  property bool locationFresh: false
  property bool weatherFresh: false
  property bool loading: false
  property bool offline: false
  property bool started: false
  property string error: ""
  property double locationUpdated: 0
  property double weatherUpdated: 0
  property string cachePayload: ""
  property bool cacheDirty: false

  readonly property bool weatherMatchesLocation: {
    if (!weather || !location || location.source !== "ip") return false;
    if (!weatherLocation) return true;
    return near(location, weatherLocation);
  }
  readonly property var activeWeather: weatherMatchesLocation ? weather : null
  readonly property bool hasWeather: activeWeather !== null
  readonly property bool weatherStale: hasWeather && !weatherFresh
  readonly property string locationSource: location && location.source === "ip"
    ? (locationFresh ? "IP" : "CACHED") : "SYSTEM"
  readonly property string timezoneId: location && location.timezone && location.timezone.id
    ? location.timezone.id : (systemZone || "UTC")
  readonly property string locationLabel: {
    if (!location) return "Location unavailable";
    if (location.source === "system") return location.city || "System location";
    const city = location.city || "";
    const region = location.region && location.region !== city ? location.region : "";
    const country = location.countryCode || location.country || "";
    return [city, region, country].filter(part => part).join(", ") || "Location unavailable";
  }

  function text(value) {
    return typeof value === "string" ? value.trim() : "";
  }
  function near(a, b) {
    return !!a && !!b && Number.isFinite(a.latitude) && Number.isFinite(a.longitude)
      && Number.isFinite(b.latitude) && Number.isFinite(b.longitude)
      && Math.abs(a.latitude - b.latitude) < 0.2 && Math.abs(a.longitude - b.longitude) < 0.2;
  }
  function normalizePoint(value) {
    if (!value) return null;
    const latitude = Number(value.latitude);
    const longitude = Number(value.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
    return { latitude: latitude, longitude: longitude };
  }
  function normalizeLocation(value, source) {
    if (!value) return null;
    const latitude = Number(value.latitude);
    const longitude = Number(value.longitude);
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90
        || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) return null;
    const zone = value.timezone || {};
    const offset = Number(zone.offset);
    return {
      city: text(value.city),
      region: text(value.region),
      country: text(value.country),
      countryCode: text(value.countryCode || value.country_code),
      latitude: latitude,
      longitude: longitude,
      timezone: {
        id: text(zone.id) || "UTC",
        abbr: text(zone.abbr),
        offset: Number.isFinite(offset) ? Math.round(offset) : null,
        utc: text(zone.utc) || (Number.isFinite(offset) ? TimeFormat.offsetLabel(offset) : "")
      },
      source: source === "system" ? "system" : "ip"
    };
  }
  function normalizeGeo(value) {
    if (!value || value.success !== true) return null;
    return normalizeLocation({
      city: value.city,
      region: value.region,
      country: value.country,
      countryCode: value.country_code,
      latitude: value.latitude,
      longitude: value.longitude,
      timezone: value.timezone
    }, "ip");
  }
  function validWeather(value) {
    return !!value && !!value.current && !!value.daily
      && Number.isFinite(Number(value.current.temperature_2m))
      && Array.isArray(value.daily.time) && value.daily.time.length > 0
      && Array.isArray(value.daily.weather_code)
      && Array.isArray(value.daily.temperature_2m_min)
      && Array.isArray(value.daily.temperature_2m_max);
  }
  function systemFromZone(zone) {
    const id = text(zone) || "UTC";
    const name = id.indexOf("/") >= 0 ? id.split("/").pop().replace(/_/g, " ") : "";
    const offset = -new Date().getTimezoneOffset() * 60;
    return {
      city: name || "System location",
      region: "",
      country: "",
      countryCode: "",
      latitude: null,
      longitude: null,
      timezone: { id: id, abbr: "", offset: offset, utc: TimeFormat.offsetLabel(offset) },
      source: "system"
    };
  }
  function offsetFor(timestamp) {
    if (location && location.source === "ip" && location.timezone
        && Number.isFinite(location.timezone.offset)) return location.timezone.offset;
    const date = new Date(Number.isFinite(timestamp) ? timestamp : Date.now());
    return -date.getTimezoneOffset() * 60;
  }

  function loadCache() {
    let raw = "";
    try { raw = cacheFile.text(); } catch (_) { return; }
    if (!raw || !raw.trim()) return;
    let data;
    try { data = JSON.parse(raw); } catch (_) { return; }
    if (!data || typeof data !== "object") return;
    const stored = normalizeLocation(data.location, "ip");
    if (stored) {
      location = stored;
      locationUpdated = Number(data.locationSaved) || 0;
    }
    if (validWeather(data.weather)) {
      weather = data.weather;
      weatherUpdated = Number(data.weatherSaved) || 0;
      weatherLocation = normalizePoint(data.weatherLocation) || (stored ? normalizePoint(stored) : null);
    }
  }
  function cacheObject() {
    return {
      version: 1,
      saved: Date.now(),
      location: location && location.source === "ip" ? location : null,
      locationSaved: locationUpdated,
      weather: weather || null,
      weatherSaved: weatherUpdated,
      weatherLocation: weatherLocation || null
    };
  }
  function saveCache() {
    if (!location || location.source !== "ip") return;
    cacheDirty = true;
    if (!cacheDirectory.running) cacheDirectory.run(["mkdir", "-p", "-m", "700", "--", Common.Paths.cache, directory], code => {
      if (code !== 0) { error = "Could not create weather cache."; return; }
      cacheDirty = false;
      cacheFile.setText(JSON.stringify(cacheObject()) + "\n");
    });
  }
  Common.Command { id: cacheDirectory }

  function activate(force) {
    started = true;
    ensureFresh(force === true);
  }
  function ensureFresh(force) {
    if (loading) return;
    if (!force && weatherUpdated > 0 && Date.now() - weatherUpdated < staleAfter && hasWeather) return;
    refresh(force);
  }
  function refresh(force) {
    if (loading) return;
    loading = true;
    started = true;
    offline = false;
    error = "";
    weatherFresh = false;
    if (location && location.source === "ip" && !force
        && Date.now() - locationUpdated < geolocateAfter) {
      fetchWeather(location);
      return;
    }
    fetchGeo(location);
  }
  function fetchGeo(fallback) {
    geoFallback = fallback || null;
    geoRequest.running = true;
    watchdog.restart();
  }
  function geoFinished(value) {
    const fresh = normalizeGeo(value);
    if (fresh) {
      location = fresh;
      locationFresh = true;
      locationUpdated = Date.now();
      saveCache();
      fetchWeather(fresh);
      return;
    }
    locationFresh = false;
    const fallback = geoFallback && geoFallback.source === "ip" && Number.isFinite(geoFallback.latitude)
      ? geoFallback : (location && location.source === "ip" && Number.isFinite(location.latitude) ? location : null);
    if (fallback) {
      if (!location) location = fallback;
      fetchWeather(fallback);
      return;
    }
    finishFailure("Offline · using system timezone");
  }
  function fetchWeather(target) {
    if (!target || !Number.isFinite(target.latitude) || !Number.isFinite(target.longitude)) {
      finishFailure("Weather unavailable");
      return;
    }
    weatherTarget = target;
    const query = [
      "latitude=" + target.latitude.toFixed(4),
      "longitude=" + target.longitude.toFixed(4),
      "current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code",
      "daily=weather_code,temperature_2m_min,temperature_2m_max",
      "timezone=auto",
      "forecast_days=7",
      "temperature_unit=" + temperatureUnit,
      "wind_speed_unit=" + windUnit
    ].join("&");
    weatherRequest.command = ["curl", "--fail", "--silent", "--show-error", "--location", "--proto", "=https",
      "--connect-timeout", "5", "--max-time", "10",
      "https://api.open-meteo.com/v1/forecast?" + query];
    weatherRequest.running = true;
    watchdog.restart();
  }
  function weatherFinished(value) {
    if (validWeather(value)) {
      weather = value;
      weatherLocation = normalizePoint(weatherTarget);
      weatherUpdated = Date.now();
      weatherFresh = true;
      offline = false;
      error = "";
      loading = false;
      const offset = Number(value.utc_offset_seconds);
      if (location && location.source === "ip" && weatherTarget && near(location, weatherTarget)
          && Number.isFinite(offset)) {
        location = Object.assign({}, location, {
          timezone: Object.assign({}, location.timezone, {
            id: text(value.timezone) || location.timezone.id,
            offset: Math.round(offset),
            utc: TimeFormat.offsetLabel(offset)
          })
        });
      }
      saveCache();
      return;
    }
    weatherFresh = false;
    finishFailure(root.hasWeather ? "Offline · showing saved weather" : "Weather update failed · check connection");
  }
  function finishFailure(message) {
    loading = false;
    offline = true;
    weatherFresh = false;
    error = message;
    if (!location) location = systemLocation || systemFromZone(systemZone);
  }

  onTemperatureUnitChanged: if (started) activate(true)
  onWindUnitChanged: if (started) activate(true)
  Component.onCompleted: {
    loadCache();
    zoneReader.running = true;
  }

  FileView {
    id: cacheFile
    atomicWrites: true
    onSaveFailed: root.error = "Could not save weather cache."
    path: root.cachePath
    blockLoading: true
    preload: true
    printErrors: false
  }
  Process {
    id: zoneReader
    command: ["timedatectl", "show", "-p", "Timezone", "--value"]
    stdout: StdioCollector { id: zoneOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: {
      root.systemZone = root.text(zoneOutput.text) || "UTC";
      root.systemLocation = root.systemFromZone(root.systemZone);
      if (!root.location || root.location.source === "system") root.location = root.systemLocation;
    }
  }
  Process {
    id: geoRequest
    command: ["curl", "--fail", "--silent", "--show-error", "--location", "--proto", "=https",
      "--connect-timeout", "5", "--max-time", "10", "https://ipwho.is/"]
    stdout: StdioCollector { id: geoOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: (code, status) => {
      watchdog.stop();
      let value = null;
      if (code === 0 && status === 0) {
        try { value = JSON.parse(geoOutput.text); } catch (_) { value = null; }
      }
      root.geoFinished(value);
    }
  }
  Process {
    id: weatherRequest
    stdout: StdioCollector { id: weatherOutput; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: (code, status) => {
      watchdog.stop();
      let value = null;
      if (code === 0 && status === 0) {
        try { value = JSON.parse(weatherOutput.text); } catch (_) { value = null; }
      }
      root.weatherFinished(value);
    }
  }
  Timer {
    id: watchdog
    interval: 20000
    onTriggered: {
      if (geoRequest.running) geoRequest.signal(15);
      if (weatherRequest.running) weatherRequest.signal(15);
    }
  }
  Timer {
    interval: root.offline ? root.retryAfter : root.refreshAfter
    running: root.started
    repeat: true
    onTriggered: root.ensureFresh(false)
  }
  Connections {
    target: root.started ? NetworkData : null
    enabled: root.started
    function onAvailableChanged() {
      if (root.started && NetworkData.available) root.ensureFresh(true);
    }
  }
}
