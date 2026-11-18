import QtQuick

QtObject {
  id: theme

  // The SDDM theme.conf object is a QQmlPropertyMap. Bracket access returns
  // undefined for missing keys; typed getters convert INI strings safely.
  required property var values

  function defined(key) {
    return values[key] !== undefined
  }

  function optionalColor(key, fallback) {
    return defined(key) && values.stringValue(key).length > 0 ? values.stringValue(key) : fallback
  }

  function resolveBackground(value) {
    if (!value)
      return ""
    if (value.indexOf("://") !== -1)
      return value.indexOf("file://") === 0 ? value : ""
    if (value.charAt(0) === "/")
      return "file://" + value
    if (value.indexOf("/") !== -1 || value.indexOf(".") !== -1)
      return Qt.resolvedUrl("../" + value)
    return Qt.resolvedUrl("../assets/backgrounds/" + value + ".jpg")
  }

  function resolveAvatar(value) {
    if (!value)
      return ""
    if (value.indexOf("://") !== -1)
      return value
    if (value.charAt(0) === "/")
      return "file://" + value
    return Qt.resolvedUrl("../" + value)
  }

  readonly property bool animations: defined("animations") ? values.boolValue("animations") : true
  readonly property bool stars: defined("stars") ? values.boolValue("stars") : true
  readonly property real starDensity: defined("starDensity") ? values.realValue("starDensity") : 1.0
  readonly property bool shootingStars: defined("shootingStars") ? values.boolValue("shootingStars") : true
  readonly property int meteorCount: defined("meteorCount") ? values.intValue("meteorCount") : 2
  readonly property real meteorAngle: defined("meteorAngle") ? values.realValue("meteorAngle") : 28
  readonly property real inactiveDim: defined("inactiveDim") ? values.realValue("inactiveDim") : 0.45
  readonly property real scale: defined("scale") ? values.realValue("scale") : 1.0
  readonly property bool backgroundDrift: defined("backgroundDrift") ? values.boolValue("backgroundDrift") : true
  readonly property string clockFormat: defined("clockFormat") ? values.stringValue("clockFormat") : "24h"
  readonly property string activationMode: defined("activationMode") ? values.stringValue("activationMode") : "click"
  readonly property bool showAvatar: defined("showAvatar") ? values.boolValue("showAvatar") : true
  readonly property bool showSession: defined("showSession") ? values.boolValue("showSession") : true
  readonly property bool showPower: defined("showPower") ? values.boolValue("showPower") : true
  readonly property bool showHostname: defined("showHostname") ? values.boolValue("showHostname") : true
  readonly property bool showKeyboard: defined("showKeyboard") ? values.boolValue("showKeyboard") : true
  readonly property string avatarOverride: defined("avatar") ? values.stringValue("avatar") : ""
  readonly property string customAvatar: resolveAvatar(avatarOverride)

  // Dark is the default; any value other than "light" falls back to dark.
  readonly property string mode: defined("mode") ? values.stringValue("mode") : "dark"
  readonly property bool light: mode === "light"

  // Values mirror docs/design-system.md and config/quickshell/settings.json.
  readonly property var darkScheme: ({
    background: "#0E1113",
    surface: "#171C1F",
    text: "#E7ECE9",
    muted: "#8D9994",
    cyan: "#7FD0BF",
    lavender: "#A9B5D9",
    gold: "#E5B873",
    alert: "#F08C7B"
  })
  readonly property var lightScheme: ({
    background: "#EEF2EF",
    surface: "#FBFCFA",
    text: "#141B1D",
    muted: "#5A6764",
    cyan: "#17675A",
    lavender: "#3B4A7A",
    gold: "#8A5B16",
    alert: "#A9361F"
  })
  readonly property var scheme: light ? lightScheme : darkScheme

  // Optional colour keys override the selected mode when set in theme.conf.
  readonly property color background: optionalColor("backgroundColor", scheme.background)
  readonly property color surface: optionalColor("surfaceColor", scheme.surface)
  readonly property color text: optionalColor("textColor", scheme.text)
  readonly property color muted: optionalColor("mutedColor", scheme.muted)
  readonly property color cyan: optionalColor("accentColor", scheme.cyan)
  readonly property color lavender: optionalColor("lavenderColor", scheme.lavender)
  readonly property color gold: optionalColor("goldColor", scheme.gold)
  readonly property color alert: optionalColor("alertColor", scheme.alert)

  // Derived tones, computed as in config/quickshell/common/Theme.qml.
  readonly property color raised: Qt.tint(surface, Qt.alpha(text, light ? 0.05 : 0.06))
  readonly property color sunken: Qt.tint(background, Qt.alpha(text, 0.03))
  readonly property color border: Qt.alpha(text, light ? 0.14 : 0.1)
  readonly property color hairline: Qt.alpha(text, 0.06)
  readonly property color scrim: Qt.alpha(background, 0.72)

  readonly property real overlay: defined("overlay") ? values.realValue("overlay") : (light ? 0.72 : 0.5)

  readonly property string font: "sans-serif"
  readonly property string mono: "JetBrainsMono Nerd Font"
  readonly property int unit: 4
  readonly property int gap: 8
  readonly property int inset: 16
  readonly property int section: 24
  readonly property int captionSize: 10
  readonly property int bodySize: 13
  readonly property int labelSize: 14
  readonly property int titleSize: 18
  readonly property int displaySize: 72
  readonly property int panelRadius: 20
  readonly property int cardRadius: 14
  readonly property int rowRadius: 10
  readonly property int controlRadius: 999
  readonly property int fieldHeight: 48
  readonly property int buttonHeight: 44
  readonly property int panelWidth: 400
  readonly property int hoverDuration: animations ? 140 : 0
  readonly property int entryDuration: animations ? 320 : 0

  readonly property string backgroundSource: {
    var value = defined("background") ? values.stringValue("background") : "aurora"
    return resolveBackground(value)
  }

  readonly property int backgroundFill: {
    var requested = defined("backgroundMode") ? values.stringValue("backgroundMode") : "fill"
    if (requested === "fit")
      return Image.PreserveAspectFit
    if (requested === "stretch")
      return Image.Stretch
    if (requested === "tile")
      return Image.Tile
    return Image.PreserveAspectCrop
  }
}
