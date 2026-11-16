pragma ComponentBehavior: Bound
import QtQuick
import "../data" as Data

// External visuals receive one live context object; see docs/quickshell.md.
Item {
  id: root
  required property var tokens
  property bool vertical: false
  property bool compact: false
  property int percent: -1
  property bool discharging: false
  property string batteryState: ""
  property bool externalPower: false
  signal activated()
  signal summaryActivated()
  readonly property string replacement: tokens.settings.value.components.battery
  readonly property bool hovered: loader.item && loader.item.hovered !== undefined ? loader.item.hovered : false
  readonly property color ink: loader.item && loader.item.ink !== undefined ? loader.item.ink : tokens.cyan
  readonly property color accent: loader.item && loader.item.accent !== undefined ? loader.item.accent : tokens.text
  readonly property bool warning: loader.item && loader.item.warning !== undefined ? loader.item.warning : false
  readonly property int step: compact ? 26 : 32
  readonly property int normalLength: 0
  implicitWidth: loader.item ? loader.item.implicitWidth : 0
  implicitHeight: loader.item ? loader.item.implicitHeight : 0
  property bool ready: false
  function load() {
    if (!ready) return;
    const external = replacement !== "";
    const url = external ? (replacement.startsWith("/") ? "file://" + replacement.split("/").map(encodeURIComponent).join("/") : Qt.resolvedUrl("../" + replacement)) : Qt.resolvedUrl("DefaultBatteryModule.qml");
    loader.setSource(url, external ? {context: root} : {
          tokens: Qt.binding(() => root.tokens),
          percent: Qt.binding(() => root.percent),
          discharging: Qt.binding(() => root.discharging),
          batteryState: Qt.binding(() => root.batteryState),
          externalPower: Qt.binding(() => root.externalPower),
          vertical: Qt.binding(() => root.vertical),
          compact: Qt.binding(() => root.compact)
    });
  }
  Component.onCompleted: { ready = true; load(); }
  onReplacementChanged: load()
  Loader {
    id: loader
    anchors.fill: parent
    onStatusChanged: if (status === Loader.Error && root.replacement) {
      console.warn("Cannot load replacement for battery; using the default visual.");
      setSource(Qt.resolvedUrl("DefaultBatteryModule.qml"), {
          tokens: Qt.binding(() => root.tokens),
          percent: Qt.binding(() => root.percent),
          discharging: Qt.binding(() => root.discharging),
          batteryState: Qt.binding(() => root.batteryState),
          externalPower: Qt.binding(() => root.externalPower),
          vertical: Qt.binding(() => root.vertical),
          compact: Qt.binding(() => root.compact)
      });
    }
  }
  Connections {
    target: loader.item
    ignoreUnknownSignals: true
    function onActivated() { root.activated(); }
    function onSummaryActivated() { root.summaryActivated(); }
  }
}
