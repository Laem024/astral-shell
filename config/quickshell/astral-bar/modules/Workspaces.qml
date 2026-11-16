pragma ComponentBehavior: Bound
import QtQuick
import "../data" as Data

// External visuals receive one live context object; see docs/quickshell.md.
Item {
  id: root
  required property var tokens
  property bool vertical: false
  property bool compact: false
  property var spaces: []
  property var specials: []
  property int active: 1
  property int count: 10
  property string activeSpecial: ""
  property string display: "icons"
  property bool interactive: true
  signal selected(int workspace)
  signal specialSelected(string name)
  readonly property string replacement: tokens.settings.value.components.workspaces
  readonly property bool hovered: loader.item && loader.item.hovered !== undefined ? loader.item.hovered : false
  readonly property color ink: loader.item && loader.item.ink !== undefined ? loader.item.ink : tokens.cyan
  readonly property color accent: loader.item && loader.item.accent !== undefined ? loader.item.accent : tokens.text
  readonly property bool warning: loader.item && loader.item.warning !== undefined ? loader.item.warning : false
  readonly property int step: compact ? 26 : 32
  readonly property int normalLength: count * step
  implicitWidth: loader.item ? loader.item.implicitWidth : 0
  implicitHeight: loader.item ? loader.item.implicitHeight : 0
  property bool ready: false
  function load() {
    if (!ready) return;
    const external = replacement !== "";
    const url = external ? (replacement.startsWith("/") ? "file://" + replacement.split("/").map(encodeURIComponent).join("/") : Qt.resolvedUrl("../" + replacement)) : Qt.resolvedUrl("DefaultWorkspaces.qml");
    loader.setSource(url, external ? {context: root} : {
          tokens: Qt.binding(() => root.tokens),
          spaces: Qt.binding(() => root.spaces),
          specials: Qt.binding(() => root.specials),
          active: Qt.binding(() => root.active),
          count: Qt.binding(() => root.count),
          activeSpecial: Qt.binding(() => root.activeSpecial),
          display: Qt.binding(() => root.display),
          interactive: Qt.binding(() => root.interactive),
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
      console.warn("Cannot load replacement for workspaces; using the default visual.");
      setSource(Qt.resolvedUrl("DefaultWorkspaces.qml"), {
          tokens: Qt.binding(() => root.tokens),
          spaces: Qt.binding(() => root.spaces),
          specials: Qt.binding(() => root.specials),
          active: Qt.binding(() => root.active),
          count: Qt.binding(() => root.count),
          activeSpecial: Qt.binding(() => root.activeSpecial),
          display: Qt.binding(() => root.display),
          interactive: Qt.binding(() => root.interactive),
          vertical: Qt.binding(() => root.vertical),
          compact: Qt.binding(() => root.compact)
      });
    }
  }
  Connections {
    target: loader.item
    ignoreUnknownSignals: true
    function onSelected(workspace) { root.selected(workspace); }
    function onSpecialSelected(name) { root.specialSelected(name); }
  }
}
