pragma ComponentBehavior: Bound
import QtQuick
import "../data" as Data

// External visuals receive one live context object; see docs/quickshell.md.
Item {
  id: root
  required property var tokens
  property bool vertical: false
  property bool compact: false
  property bool recording: false
  property string captureState: "idle"
  property int duration: 0
  signal clicked()
  readonly property string replacement: tokens.settings.value.components.capture
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
    const url = external ? (replacement.startsWith("/") ? "file://" + replacement.split("/").map(encodeURIComponent).join("/") : Qt.resolvedUrl("../" + replacement)) : Qt.resolvedUrl("DefaultCaptureModule.qml");
    loader.setSource(url, external ? {context: root} : {
          tokens: Qt.binding(() => root.tokens),
          recording: Qt.binding(() => root.recording),
          captureState: Qt.binding(() => root.captureState),
          duration: Qt.binding(() => root.duration),
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
      console.warn("Cannot load replacement for capture; using the default visual.");
      setSource(Qt.resolvedUrl("DefaultCaptureModule.qml"), {
          tokens: Qt.binding(() => root.tokens),
          recording: Qt.binding(() => root.recording),
          captureState: Qt.binding(() => root.captureState),
          duration: Qt.binding(() => root.duration),
          vertical: Qt.binding(() => root.vertical),
          compact: Qt.binding(() => root.compact)
      });
    }
  }
  Connections {
    target: loader.item
    ignoreUnknownSignals: true
    function onClicked() { root.clicked(); }
  }
}
