pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../../common" as Design
import "../components" as Components

Item {
  id: root
  objectName: "workspaces"
  required property Design.Theme tokens
  required property var spaces
  required property var specials
  required property int active
  required property int count
  property string activeSpecial: ""
  property string display: "icons"
  property bool vertical: false
  property bool compact: false
  property bool interactive: true
  readonly property int step: compact ? 26 : 32
  readonly property int normalLength: count * step
  readonly property int length: normalLength + 10 + step
  property int hoveredIndex: -1
  readonly property Item hoveredItem: hoveredIndex < 0 ? null : nodes.itemAt(hoveredIndex)
  signal selected(int workspace)
  signal specialSelected(string name)
  implicitWidth: vertical ? 46 : length
  implicitHeight: vertical ? length : 40
  function activate(workspace: int): void { selected(workspace); }
  function specialColor(name: string): color {
    const identity = name.replace(/^special:/, "");
    if (identity === "magic") return tokens.gold;
    if (identity === "music") return tokens.lavender;
    if (identity === "communication") return tokens.cyan;
    const palette = [tokens.gold, tokens.lavender, tokens.cyan, tokens.alert];
    let hash = 0;
    for (let index = 0; index < identity.length; index++)
      hash = (hash * 31 + identity.charCodeAt(index)) >>> 0;
    return palette[hash % palette.length];
  }
  // A sliding tab preserves spatial continuity between numbered positions.
  Rectangle {
    objectName: "workspaceSelection"
    x: root.vertical ? (root.width - width) / 2 : (root.active - 1) * root.step + (root.step - width) / 2
    y: root.vertical ? (root.active - 1) * root.step + (root.step - height) / 2 : (root.height - height) / 2 - 2
    width: 24; height: 24
    radius: 5
    color: Qt.alpha(root.tokens.cyan, 0.14)
    border.color: root.tokens.cyan
    Rectangle {
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: 10; height: 2
      color: root.tokens.alert
    }
    Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
    opacity: root.activeSpecial || root.active < 1 ? 0 : 1
    Behavior on x { NumberAnimation { duration: root.tokens.workspaceDuration; easing.type: Easing.InOutCubic } }
    Behavior on y { NumberAnimation { duration: root.tokens.workspaceDuration; easing.type: Easing.InOutCubic } }
    Behavior on opacity { NumberAnimation { duration: root.tokens.hoverDuration } }
  }

  Repeater {
    id: nodes
    model: root.count + 1
    Item {
      id: node
      objectName: "workspace-" + (special ? String(info.identity || info.name || "special") : String(workspaceId))
      readonly property bool hovered: hover.hovered
      required property int index
      readonly property bool special: index >= root.count
      readonly property var info: special ? (root.specials[0] || {name: "", apps: 0}) : (root.spaces[index] || {apps: 0})
      readonly property int workspaceId: special ? 0 : (info.id || index + 1)
      readonly property int apps: info.apps || 0
      readonly property bool current: special ? !!root.activeSpecial && root.activeSpecial === info.name : !root.activeSpecial && index + 1 === root.active
      readonly property color ink: special ? (current ? specialInk : root.tokens.muted)
        : current ? root.tokens.text : (hovered ? root.tokens.cyan : (apps ? root.tokens.text : root.tokens.muted))
      readonly property color specialInk: root.specialColor(root.activeSpecial)
      readonly property real offset: index * root.step + (special ? 10 : 0)
      x: root.vertical ? 0 : offset
      y: root.vertical ? offset : 0
      width: root.vertical ? root.width : root.step
      height: root.vertical ? root.step : root.height
      Accessible.role: Accessible.Button
      Accessible.name: special && !current ? "Special workspace · closed"
        : (special ? "Special workspace " + info.name : "Workspace " + workspaceId) + " · " + apps + " open apps"
      Text {
        id: glyph
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.vertical ? 0 : -2
        objectName: "workspaceGlyph-" + node.index
        visible: !node.special && root.display === "numbers"
        text: String(node.workspaceId)
        color: node.ink
        font.family: root.tokens.mono
        font.pixelSize: 12
        Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
      }
      Shape {
        objectName: "workspaceIcon-" + node.index
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.vertical ? 0 : -2
        width: 20; height: 20
        visible: !node.special && root.display === "icons"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: node.ink
          strokeWidth: 1.3
          joinStyle: ShapePath.RoundJoin
          fillColor: node.current ? node.ink : "transparent"
          startX: 4; startY: 7
          PathLine { x: 19; y: 7 }
          PathLine { x: 16; y: 13 }
          PathLine { x: 1; y: 13 }
          PathLine { x: 4; y: 7 }
        }
      }
      Item {
        objectName: "specialWorkspacePlus"
        visible: node.special
        opacity: node.current ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: root.tokens.hoverDuration } }
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.vertical ? 0 : -2
        width: 12; height: 12
        Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; color: node.ink }
        Rectangle { anchors.centerIn: parent; width: 2; height: 12; radius: 1; color: node.ink }
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.vertical ? node.height - 3 : node.height - 5
        spacing: 2
        Repeater {
          model: Math.min(node.apps, 3)
          Rectangle { width: 2; height: 2; radius: 1; color: node.current ? (node.special ? node.specialInk : root.tokens.gold) : root.tokens.lavender }
        }
      }
      Rectangle {
        objectName: "specialWorkspaceSelection"
        z: -1
        visible: node.special && node.current
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.vertical ? 0 : -2
        width: 24; height: 24; radius: 5
        color: Qt.alpha(node.specialInk, 0.12); border.color: node.specialInk
        Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
        Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
      }
      Components.NeonOutline {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.vertical ? 0 : -2
        width: 24; height: 24
        tokens: root.tokens
        accent: node.special ? node.specialInk : root.tokens.cyan
        active: node.hovered && (!node.special || node.current)
      }
      HoverHandler {
        id: hover
        onHoveredChanged: {
          if (hovered) root.hoveredIndex = node.index;
          else if (root.hoveredIndex === node.index) root.hoveredIndex = -1;
        }
      }
      TapHandler {
        enabled: root.interactive && (!node.special || node.current)
        onTapped: {
          if (node.special) root.specialSelected(String(node.info.identity || node.info.name));
          else root.activate(node.workspaceId);
        }
      }
    }
  }
}
