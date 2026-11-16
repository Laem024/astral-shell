import QtQuick

QtObject {
  id: theme

  // The SDDM theme.conf object is a QQmlPropertyMap. Bracket access returns
  // undefined for missing keys; typed getters convert INI strings safely.
  required property var values

  function defined(key) {
    return values[key] !== undefined
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
  readonly property real overlay: defined("overlay") ? values.realValue("overlay") : 0.24
  readonly property real inactiveDim: defined("inactiveDim") ? values.realValue("inactiveDim") : 0.45
  readonly property real glassOpacity: defined("glassOpacity") ? values.realValue("glassOpacity") : 0.52
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

  readonly property color background: defined("backgroundColor") ? values.stringValue("backgroundColor") : "#151918"
  readonly property color surface: defined("surfaceColor") ? values.stringValue("surfaceColor") : "#202629"
  readonly property color text: defined("textColor") ? values.stringValue("textColor") : "#F4EEDF"
  readonly property color muted: defined("mutedColor") ? values.stringValue("mutedColor") : "#B1B5AD"
  readonly property color cyan: defined("accentColor") ? values.stringValue("accentColor") : "#B1D7CB"
  readonly property color lavender: defined("lavenderColor") ? values.stringValue("lavenderColor") : "#C6CCD2"
  readonly property color gold: defined("goldColor") ? values.stringValue("goldColor") : "#E4B882"
  readonly property color alert: defined("alertColor") ? values.stringValue("alertColor") : "#FF957C"
  readonly property color border: Qt.alpha(muted, 0.18)

  // Glass surfaces: translucent layers over the aurora backdrop. Without a
  // scene-graph blur the tint is kept dark enough to preserve contrast.
  readonly property color glass: Qt.alpha(surface, glassOpacity)
  readonly property color glassDeep: Qt.alpha(surface, Math.min(1, glassOpacity + 0.18))
  readonly property color glassSoft: Qt.alpha(background, 0.42)
  readonly property color glassLine: Qt.alpha(text, 0.1)
  readonly property color glassEdge: Qt.alpha(text, 0.17)
  readonly property color glassSheen: Qt.alpha("#FFFFFF", 0.08)
  readonly property color shadow: Qt.rgba(0.02, 0.03, 0.03, 0.55)

  readonly property string font: "sans-serif"
  readonly property string mono: "JetBrainsMono Nerd Font"
  readonly property int unit: 4
  readonly property int gap: 8
  readonly property int padding: 12
  readonly property int inset: 16
  readonly property int section: 24
  readonly property int textSize: 12
  readonly property int labelSize: 14
  readonly property int iconSize: 20
  readonly property int panelRadius: 30
  readonly property int fieldRadius: 16
  readonly property int fieldHeight: 56
  readonly property int panelWidth: 452
  readonly property int hoverDuration: animations ? 140 : 0
  readonly property int entryDuration: animations ? 420 : 0

  readonly property string backgroundSource: {
    var value = defined("background") ? values.stringValue("background") : "aurora"
    return resolveBackground(value)
  }

  readonly property int backgroundFill: {
    var mode = defined("backgroundMode") ? values.stringValue("backgroundMode") : "fill"
    if (mode === "fit")
      return Image.PreserveAspectFit
    if (mode === "stretch")
      return Image.Stretch
    if (mode === "tile")
      return Image.Tile
    return Image.PreserveAspectCrop
  }
}
